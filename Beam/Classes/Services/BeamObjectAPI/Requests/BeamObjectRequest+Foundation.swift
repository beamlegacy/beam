import Foundation
import BeamCore

extension BeamObjectRequest {
    @discardableResult
    // return multiple errors, as the API might return more than one.
    func save(_ beamObject: BeamObject,
              _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = try saveBeamObjectParameters(beamObject)
        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object", variables: parameters)

        if beamObject.dataChecksum == beamObject.previousChecksum {
            Logger.shared.logWarning("Sent checksum and previousChecksum the same: \(beamObject.dataChecksum ?? "-") for \(beamObject.description), this network call could have been avoided.",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("Sent checksum: \(beamObject.dataChecksum ?? "-"), previousChecksum: \(beamObject.previousChecksum ?? "-") for \(beamObject.description)",
                                   category: .beamObjectNetwork)
        }

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UpdateBeamObject, Error>) in
            do {
                try beamObject.decrypt()
            } catch {
                completion(.failure(error))
                return
            }

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
    func delete<T: BeamObjectProtocol>(object: T,
                                       _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = BeamObjectIdParameters(id: object.beamObjectId,
                                                beamObjectType: type(of: object).beamObjectType.rawValue)
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
    func delete(beamObject: BeamObject,
                _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws  -> URLSessionDataTask {
        let parameters = BeamObjectIdParameters(id: beamObject.id, beamObjectType: beamObject.beamObjectType)
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
    func deleteAll(beamObjectType: BeamObjectObjectType? = nil,
                   _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = DeleteAllBeamObjectsParameters(beamObjectType: beamObjectType?.rawValue)
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
                  beamObjectType: String? = nil,
                  _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType)

        return try fetchAllWithFile("beam_objects", parameters, completion)
    }

    @discardableResult
    func fetchAllChecksums(receivedAtAfter: Date? = nil,
                           ids: [UUID]? = nil,
                           beamObjectType: String? = nil,
                           _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType)

        return try fetchAllWithFile("beam_object_checksums", parameters, completion)
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
                            try $0.setTimestamps()
                            return $0
                        } catch EncryptionManagerError.authenticationFailure {
                            Logger.shared.logError("Can't decrypt \($0)", category: .beamObjectNetwork)
                        } catch BeamObject.BeamObjectError.differentEncryptionKey {
                            let privateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
                            Logger.shared.logError("Can't decrypt beam object, private key \($0.privateKeySignature ?? "-") unavailable. Current private key: \(privateKeySignature).", category: .beamObjectNetwork)
                        }

                        return nil
                    }

                    if decryptedObjects.count < beamObjects.count {
                        UserAlert.showError(message: "Encryption error",
                                            informativeText: "\(beamObjects.count - decryptedObjects.count) objects we fetched couldn't be decrypted, check logs for more details. You probably have a different local private key than the one used to encrypt objects on the API side. Either use a different account, or copy/paste your private key in the advanced settings.")
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
    func fetch<T: BeamObjectProtocol> (object: T,
                                       _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: "beam_object",
                          beamObjectID: object.beamObjectId,
                          beamObjectType: type(of: object).beamObjectType.rawValue,
                          completionHandler)
    }

    @discardableResult
    func fetch(beamObject: BeamObject,
               _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: "beam_object",
                          beamObjectID: beamObject.id,
                          beamObjectType: beamObject.beamObjectType,
                          completionHandler)
    }

    @discardableResult
    func fetchMinimalBeamObject(beamObject: BeamObject,
                                _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: "beam_object_updated_at",
                          beamObjectID: beamObject.id,
                          beamObjectType: beamObject.beamObjectType,
                          completionHandler)
    }

    @discardableResult
    func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T,
                                                       _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: "beam_object_updated_at",
                          beamObjectID: object.beamObjectId,
                          beamObjectType: type(of: object).beamObjectType.rawValue,
                          completionHandler)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchWithFile(filename: String,
                               beamObjectID: UUID,
                               beamObjectType: String,
                               _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectIdParameters(id: beamObjectID, beamObjectType: beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<FetchBeamObject, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let fetchBeamObject):
                do {
                    try fetchBeamObject.decrypt()
                    try fetchBeamObject.setTimestamps()
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
