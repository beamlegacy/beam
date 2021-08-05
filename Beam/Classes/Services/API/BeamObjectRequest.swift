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
        let privateKey: String?
        var errors: [UserErrorData]?

        init(beamObject: BeamObject?, privateKey: String?) {
            self.beamObject = beamObject
            self.privateKey = privateKey
        }
    }

    class DeleteBeamObject: UpdateBeamObject { }

    struct UpdateBeamObjects: Codable, Errorable {
        let beamObjects: [BeamObject]?
        let privateKey: String?
        var errors: [UserErrorData]?
    }

    struct BeamObjectsParameters: Encodable {
        let updatedAtAfter: Date?
    }

    internal func saveBeamObjectParameters(_ beamObject: BeamObject) throws -> UpdateBeamObject {
        try beamObject.encrypt()

        #if DEBUG
        return UpdateBeamObject(beamObject: beamObject, privateKey: EncryptionManager.shared.privateKey().asString())
        #else
        return UpdateBeamObject(beamObject: beamObject, privateKey: nil)
        #endif

    }

    internal func saveBeamObjectsParameters(_ beamObjects: [BeamObject]) throws -> UpdateBeamObjects {
        let result: [BeamObject] = try beamObjects.map {
            try $0.encrypt()
            return $0
        }

        #if DEBUG
        return UpdateBeamObjects(beamObjects: result, privateKey: EncryptionManager.shared.privateKey().asString())
        #else
        return UpdateBeamObjects(beamObjects: result, privateKey: nil)
        #endif
    }
}

// MARK: Foundation
extension BeamObjectRequest {
    @discardableResult
    // return multiple errors, as the API might return more than one.
    func save(_ beamObject: BeamObject,
              _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let saveObject = beamObject.copy()

        let parameters = try saveBeamObjectParameters(saveObject)
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

        let saveObjects: [BeamObject] = beamObjects.map {
            $0.copy()
        }

        do {
            parameters = try saveBeamObjectsParameters(saveObjects)
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
                _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = BeamObjectIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<DeleteBeamObject, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let deletedBeamObject):
                guard let object = deletedBeamObject.beamObject else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }

                // To be safe, but deleted objects won't fetch `data`
                try? object.decrypt()

                completion(.success(object))
            }
        }
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
                guard let beamObjects = me.beamObjects else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }

                /*
                 When fetching all beam objects, we decrypt them if needed. We might have decryption issue
                 like not having the key it was encrypted with. In such case we filter those out as the calling
                 code wouldn't know what to do with it anyway.
                 */
                do {
                    let decryptedObjects: [BeamObject] = try beamObjects.compactMap {
                        do {
                            try $0.decrypt()
                            return $0
                        } catch EncryptionManagerError.authenticationFailure {
                            Logger.shared.logError("Can't decrypt \($0)", category: .beamObjectNetwork)
                        }

                        return nil
                    }

                    completion(.success(decryptedObjects))
                } catch {
                    // Will catch anything but encryption errors
                    completion(.failure(error))
                    return
                }
            }
        }
    }

    @discardableResult
    func fetch(_ beamObjectID: UUID,
               _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile("beam_object", beamObjectID, completionHandler)
    }

    @discardableResult
    func fetchMinimalBeamObject(_ beamObjectID: UUID,
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
                    // Will catch decrypting errors
                    completionHandler(.failure(error))
                    return
                }

                completionHandler(.success(fetchBeamObject))
            }
        }
    }
}
