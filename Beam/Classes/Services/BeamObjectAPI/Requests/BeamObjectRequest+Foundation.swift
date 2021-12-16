import Foundation
import BeamCore

// swiftlint:disable function_length file_length

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
    func save(_ beamObjects: [BeamObject],
              _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask? {
        var filesUpload: [GraphqlFileUpload] = []
        var saveBeamObjects: [BeamObject] = []
        var sameChecksum = false

        for (index, beamObject) in beamObjects.enumerated() {
            let saveObject = beamObject.copy()
            try saveObject.encrypt()

            if saveObject.dataChecksum == saveObject.previousChecksum {
                sameChecksum = true
            }

            if let data = saveObject.data {
                filesUpload.append(GraphqlFileUpload(contentType: "application/octet-stream",
                                                     binary: data,
                                                     filename: "\(saveObject.id).enc",
                                                     variableName: "beamObjects.\(index).largeData"))
            }

            saveObject.data = nil
            saveBeamObjects.append(saveObject)
        }

        if sameChecksum {
            Logger.shared.logWarning("Some objects have the same checksum and previousChecksum, they could have been avoided.",
                                     category: .beamObjectNetwork)
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
    func fetchAllWithDataUrl(receivedAtAfter: Date? = nil,
                             ids: [UUID]? = nil,
                             beamObjectType: String? = nil,
                             _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType)

        return try fetchAllWithFile("beam_objects_data_url", parameters, completion)
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
    // swiftlint:disable:next function_body_length cyclomatic_complexity
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
                 We cover all cases:
                 - if `dataUrl` was requested, it will fetch the data in another network call, set `data` then return the object
                 - if `dataUrl` wasn't requested, it just returns the object
                 */

                let callback = {
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

                guard !beamObjects.compactMap({ $0.dataUrl }).isEmpty else {
                    callback()
                    return
                }

                let group = DispatchGroup()
                let lock = DispatchSemaphore(value: 1)

                // TODO: are all those fetches optimized, what happens when we have 1,000 objects?
                // Could we limit the amount of parallel calls? Can we stream multiple into the same HTTP Request?
                for beamObject in beamObjects {
                    guard let dataUrl = beamObject.dataUrl else { continue }

                    do {
                        group.enter()
                        try self.fetchDataFromUrl(urlString: dataUrl) { result in
                            switch result {
                            case .failure(let error):
                                Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                            case .success(let data):
                                lock.wait()
                                beamObject.data = data
                                lock.signal()
                            }
                            group.leave()
                        }
                    } catch {
                        Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                    }

                    // This code is multi-threaded, with vinyl once network calls are saved, it might take one for another
                    // because not in the same order, adding a sleep should fix that
                    if EnvironmentVariables.env == "test" {
                        usleep(100000) // 0.1s
                    }
                }

                group.wait()

                callback()
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
    func fetchWithDataUrl(beamObject: BeamObject,
                          _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: "beam_object_data_url",
                          beamObjectID: beamObject.id,
                          beamObjectType: beamObject.beamObjectType,
                          completionHandler)
    }

    @discardableResult
    func fetchWithDataUrl<T: BeamObjectProtocol>(object: T,
                                                 _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: "beam_object_data_url",
                          beamObjectID: object.beamObjectId,
                          beamObjectType: type(of: object).beamObjectType.rawValue,
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
                /*
                 We cover all cases:
                 - if `dataUrl` was requested, it will fetch the data in another network call, set `data` then return the object
                 - if `dataUrl` wasn't requested, it just returns the object
                 */
                let callback = {
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

                guard let dataUrl = fetchBeamObject.dataUrl else {
                    callback()
                    return
                }

                do {
                    try self.fetchDataFromUrl(urlString: dataUrl) { result in
                        switch result {
                        case .failure(let error): completionHandler(.failure(error))
                        case .success(let data):
                            fetchBeamObject.data = data
                            callback()
                        }
                    }
                } catch {
                    completionHandler(.failure(error))
                }
            }
        }
    }

    enum BeamObjectRequestError: Error {
        case malformattedURL
        case not200
    }

    @discardableResult
    private func fetchDataFromUrl(urlString: String,
                                  _ completionHandler: @escaping (Swift.Result<Data, Error>) -> Void) throws -> URLSessionDataTask {

        guard let url = URL(string: urlString) else {
             throw BeamObjectRequestError.malformattedURL
        }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)"
        ]

        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        // We want to send the `Bearer` token to our hosts only
        if let host = url.host,
           let accessToken = AuthenticationManager.shared.accessToken {
            request.setValue("Bearer " + accessToken,
                             forHTTPHeaderField: "Authorization")
        } else {
            assert(false)
        }

        let session = BeamURLSession.shared
        let localTimer = BeamDate.now
        let task = session.dataTask(with: request) { (data, response, error) -> Void in
            Logger.shared.logDebug("[\(data?.count.byteSize ?? "-")] \((response as? HTTPURLResponse)?.statusCode ?? 0) \(urlString)",
                                   category: .network,
                                   localTimer: localTimer)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                      completionHandler(.failure(error ?? BeamObjectRequestError.not200))

                      return
                  }

            completionHandler(.success(data))
        }

        task.resume()
        return task
    }
}
