import Foundation
import CommonCrypto
import PromiseKit
import Promises

class BeamObjectRequest: APIRequest {
    struct DeleteAllBeamObjects: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    struct BeamObjectIdParameters: Encodable {
        let id: String
    }

    class FetchBeamObject: BeamObjectAPIType, Errorable {
        static let codingKey = "beamObject"
        let errors: [UserErrorData]? = nil
    }

    class UpdateBeamObject: Codable, Errorable {
        let beamObject: BeamObjectAPIType?
        var errors: [UserErrorData]?

        init(beamObject: BeamObjectAPIType?) {
            self.beamObject = beamObject
        }
    }

    class DeleteBeamObject: UpdateBeamObject { }

    struct UpdateBeamObjects: Codable, Errorable {
        let beamObjects: [BeamObjectAPIType]?
        var errors: [UserErrorData]?
    }

    struct BeamObjectsParameters: Encodable {
        let updatedAtAfter: Date?
    }

    internal func saveBeamObjectParameters(_ beamObject: BeamObjectAPIType) throws -> UpdateBeamObject {
        try beamObject.encrypt()

        return UpdateBeamObject(beamObject: beamObject)
    }

    internal func saveBeamObjectsParameters(_ beamObjects: [BeamObjectAPIType]) throws -> UpdateBeamObjects {
        let result: [BeamObjectAPIType] = try beamObjects.map {
            try $0.encrypt()
            return $0
        }

        return UpdateBeamObjects(beamObjects: result)
    }

    internal func encryptAllBeamObjects(_ beamObjects: [BeamObjectAPIType]) throws {
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
    func save(_ beamObject: BeamObjectAPIType,
              _ completion: @escaping (Swift.Result<UpdateBeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = try saveBeamObjectParameters(beamObject)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UpdateBeamObject, Error>) in

            switch result {
            case .failure: completion(result)
            case .success(let updateBeamObject):
                updateBeamObject.beamObject?.previousChecksum = beamObject.dataChecksum
                completion(.success(updateBeamObject))
            }
        }
    }

    @discardableResult
    func saveAll(_ beamObjects: [BeamObjectAPIType],
                 _ completionHandler: @escaping (Swift.Result<UpdateBeamObjects, Error>) -> Void) throws -> URLSessionDataTask? {
        var parameters: UpdateBeamObjects

        do {
            parameters = try saveBeamObjectsParameters(beamObjects)
        } catch {
            completionHandler(.failure(error))
            return nil
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func delete(_ id: String,
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
                  _ completion: @escaping (Swift.Result<[BeamObjectAPIType], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(updatedAtAfter: updatedAtAfter)

        return try fetchAllWithFile("beam_objects", parameters, completion)
    }

    @discardableResult
    private func fetchAllWithFile<T: Encodable>(_ filename: String,
                                                _ parameters: T,
                                                _ completion: @escaping (Swift.Result<[BeamObjectAPIType], Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<Me, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let me):
                if let beamObjects = me.beamObjects {
                    do {
                        if Configuration.encryptionEnabled {
                            try beamObjects.forEach { try $0.decrypt() }
                        }
                    } catch {
                        // Will catch unencryption errors
                        completion(.failure(error))
                        return
                    }

                    completion(.success(beamObjects))
                } else {
                    completion(.failure(APIRequestError.parserError))
                }
            }
        }
    }

    @discardableResult
    func fetch(_ beamObjectID: String,
               _ completionHandler: @escaping (Swift.Result<BeamObjectAPIType, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile("beam_object", beamObjectID, completionHandler)
    }

    @discardableResult
    func fetchUpdatedAt(_ beamObjectID: String,
                        _ completionHandler: @escaping (Swift.Result<BeamObjectAPIType, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile("beam_object_updated_at", beamObjectID, completionHandler)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchWithFile(_ filename: String,
                               _ beamObjectID: String,
                               _ completionHandler: @escaping (Swift.Result<BeamObjectAPIType, Error>) -> Void) throws -> URLSessionDataTask {
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
