import Foundation
import BeamCore

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
    func deleteAll(beamObjectType: String? = nil,
                   _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = DeleteAllBeamObjectsParameters(beamObjectType: beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_beam_objects", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<DeleteAllBeamObjects, Error>) in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let deletedBeamObjects):
                guard deletedBeamObjects.success ?? false else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }
                completion(.success(true))
            }
        }
    }

    @discardableResult
    func fetchAll(receivedAtAfter: Date? = nil,
                  ids: [UUID]? = nil,
                  _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter, ids: ids)

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
