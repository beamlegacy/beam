import Foundation
import BeamCore

extension BeamObjectRequest {
    @discardableResult
    // return multiple errors, as the API might return more than one.
    // swiftlint:disable:next function_body_length
    func save(_ beamObject: BeamObject,
              _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let saveObject = beamObject.copy()

        try saveObject.encrypt()

        // Multipart version of the encrypted object
        var fileUpload: GraphqlFileUpload?

        if let data = saveObject.data {
            fileUpload = GraphqlFileUpload(contentType: "application/octet-stream",
                                           binary: data,
                                           filename: "\(saveObject.id).enc",
                                           variableName: "beamObject.largeData")

            saveObject.data = nil
        }

        let parameters = UpdateBeamObject(beamObject: saveObject, privateKey: nil)

        #if DEBUG
        parameters.privateKey = EncryptionManager.shared.privateKey().asString()
        #endif

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object",
                                                  variables: parameters,
                                                  files: [fileUpload].compactMap { $0 })

        if saveObject.dataChecksum == saveObject.previousChecksum {
            Logger.shared.logWarning("Sent checksum and previousChecksum the same: \(saveObject.dataChecksum ?? "-") for \(saveObject.description), this network call could have been avoided.",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("Sent checksum: \(saveObject.dataChecksum ?? "-"), previousChecksum: \(saveObject.previousChecksum ?? "-") for \(saveObject.description)",
                                   category: .beamObjectNetwork)
        }

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
    // return multiple errors, as the API might return more than one.
    func saveInline(_ beamObject: BeamObject,
                    _ completion: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        let saveObject = beamObject.copy()

        try saveObject.encrypt()

        let parameters = try saveBeamObjectParameters(saveObject)

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object",
                                                  variables: parameters)

        if saveObject.dataChecksum == saveObject.previousChecksum {
            Logger.shared.logWarning("Sent checksum and previousChecksum the same: \(saveObject.dataChecksum ?? "-") for \(saveObject.description), this network call could have been avoided.",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("Sent checksum: \(saveObject.dataChecksum ?? "-"), previousChecksum: \(saveObject.previousChecksum ?? "-") for \(saveObject.description)",
                                   category: .beamObjectNetwork)
        }

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
    func save(_ beamObjects: [BeamObject],
              _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask? {
        var filesUpload: [GraphqlFileUpload] = []
        var saveBeamObjects: [BeamObject] = []

        for (index, beamObject) in beamObjects.enumerated() {
            let saveObject = beamObject.copy()
            try saveObject.encrypt()

            if let data = saveObject.data {
                filesUpload.append(GraphqlFileUpload(contentType: "application/octet-stream",
                                                     binary: data,
                                                     filename: "\(saveObject.id).enc",
                                                     variableName: "beamObjects.\(index).largeData"))
            }

            saveObject.data = nil
            saveBeamObjects.append(saveObject)
        }

        var parameters = UpdateBeamObjects(beamObjects: saveBeamObjects, privateKey: nil)

        #if DEBUG
        parameters.privateKey = EncryptionManager.shared.privateKey().asString()
        #endif

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects",
                                                  variables: parameters,
                                                  files: filesUpload)

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
    func saveInline(_ beamObjects: [BeamObject],
                    _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask? {
        var parameters: UpdateBeamObjects

        let saveObjects: [BeamObject] = beamObjects.map {
            $0.copy()
        }

        parameters = try saveBeamObjectsParameters(saveObjects)

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
