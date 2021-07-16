import Foundation
import CommonCrypto
import PromiseKit
import Promises
import BeamCore

class BeamObjectRequest: APIRequest {
    struct DeleteAllBeamObjects: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    struct BeamObjectIdParameters: Encodable {
        let id: UUID
    }

    class FetchBeamObject: BeamObject, Errorable, APIResponseCodingKeyProtocol {
        static let codingKey = "beamObject"
        let errors: [UserErrorData]? = nil
    }

    class UpdateBeamObject: Codable, Errorable {
        let beamObject: BeamObject?
        var errors: [UserErrorData]?

        init(beamObject: BeamObject?) {
            self.beamObject = beamObject
        }
    }

    class DeleteBeamObject: UpdateBeamObject { }

    struct UpdateBeamObjects: Codable, Errorable {
        let beamObjects: [BeamObject]?
        var errors: [UserErrorData]?
    }

    struct BeamObjectsParameters: Encodable {
        let updatedAtAfter: Date?
    }

    internal func saveBeamObjectParameters(_ beamObject: BeamObject) throws -> UpdateBeamObject {
        try beamObject.encrypt()

        return UpdateBeamObject(beamObject: beamObject)
    }

    internal func saveBeamObjectsParameters(_ beamObjects: [BeamObject]) throws -> UpdateBeamObjects {
        let result: [BeamObject] = try beamObjects.map {
            try $0.encrypt()
            return $0
        }

        return UpdateBeamObjects(beamObjects: result)
    }

    internal func encryptAllBeamObjects(_ beamObjects: [BeamObject]) throws {
        guard Configuration.encryptionEnabled else { return }
        try beamObjects.forEach {
            try $0.encrypt()
            $0.data = $0.encryptedData
        }
    }
}

// MARK: Foundation
extension BeamObjectRequest {
    @discardableResult
    // return multiple errors, as the API might return more than one.
    func save(_ beamObject: BeamObject,
              _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = try saveBeamObjectParameters(beamObject)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UpdateBeamObject, Error>) in

            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let updateBeamObject):
                guard let beamObject = updateBeamObject.beamObject else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }
                beamObject.previousChecksum = beamObject.dataChecksum
                completion(.success(beamObject))
            }
        }
    }

    @discardableResult
    func saveAll(_ beamObjects: [BeamObject],
                 _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask? {
        var parameters: UpdateBeamObjects

        do {
            parameters = try saveBeamObjectsParameters(beamObjects)
        } catch {
            completion(.failure(error))
            return nil
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UpdateBeamObjects, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let updateBeamObjects):
                guard let beamObjects = updateBeamObjects.beamObjects else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }

                completion(.success(beamObjects))
            }
        }
    }

    @discardableResult
    func delete(_ id: UUID,
                _ completion: @escaping (Swift.Result<DeleteBeamObject, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = BeamObjectIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func deleteAll(_ completion: @escaping (Swift.Result<DeleteAllBeamObjects, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_beam_objects", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func fetchAll(_ updatedAtAfter: Date? = nil,
                  _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(updatedAtAfter: updatedAtAfter)

        return try fetchAllWithFile("beam_objects", parameters, completion)
    }

    @discardableResult
    private func fetchAllWithFile<T: Encodable>(_ filename: String,
                                                _ parameters: T,
                                                _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UserMe, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let me):
                guard var beamObjects = me.beamObjects else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }

                var beamObjectErrors = Set<UUID>()

                /*
                 When fetching all beam objects, we decrypt them if needed. We might have decryption issue
                 like not having the key it was encrypted with. In such case we filter those out as the calling
                 code wouldn't know what to do with it anyway.
                 */

                do {
                    if Configuration.encryptionEnabled {
                        try beamObjects.forEach {
                            do {
                                try $0.decrypt()
                            } catch EncryptionManagerError.authenticationFailure {
                                // Could not decrypt, will remove it from the results
                                beamObjectErrors.insert($0.id)
                            }
                        }
                    }
                } catch {
                    // Will catch anything but encryption errors
                    completion(.failure(error))
                    return
                }

                if !beamObjectErrors.isEmpty {
                    // Remove error elements
                    beamObjects = beamObjects.filter { !beamObjectErrors.contains($0.id) }
                    Logger.shared.logError("Removed \(beamObjectErrors.count) objects: \(beamObjectErrors)",
                                           category: .beamObjectNetwork)
                }

                completion(.success(beamObjects))
            }
        }
    }

    @discardableResult
    func fetch(_ beamObjectID: UUID,
               _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile("beam_object", beamObjectID, completionHandler)
    }

    @discardableResult
    func fetchUpdatedAt(_ beamObjectID: UUID,
                        _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile("beam_object_updated_at", beamObjectID, completionHandler)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchWithFile(_ filename: String,
                               _ beamObjectID: UUID,
                               _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectIdParameters(id: beamObjectID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<FetchBeamObject, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let fetchBeamObject):
                do {
                    try fetchBeamObject.decrypt()
                } catch {
                    // Will catch uncrypting errors
                    completionHandler(.failure(error))
                    return
                }

                completionHandler(.success(fetchBeamObject))
            }
        }
    }
}
