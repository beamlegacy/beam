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

        if EnvironmentVariables.beamObjectSendPrivateKey {
            parameters.privateKey = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
        }

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
              _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask? {
        var filesUpload: [GraphqlFileUpload] = []
        var saveBeamObjects: [BeamObject] = []
        var sameChecksum = 0

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)

        for (index, beamObject) in beamObjects.enumerated() {
            let saveObject = beamObject.copy()
            try saveObject.encrypt()

            if saveObject.dataChecksum == checksums[saveObject] {
                sameChecksum += 1
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

        if sameChecksum > 0 {
            Logger.shared.logWarning("\(sameChecksum) objects have the same checksum and previousChecksum, they could have been avoided.",
                                     category: .beamObjectNetwork)
        }

        var parameters = UpdateBeamObjects(beamObjects: saveBeamObjects, privateKey: nil)

        if EnvironmentVariables.beamObjectSendPrivateKey {
            parameters.privateKey = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects",
                                                  variables: parameters,
                                                  files: filesUpload)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UpdateBeamObjects, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(true))
            }
        }
    }

    @discardableResult
    func saveInline(_ beamObjects: [BeamObject],
                    _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask? {
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
            case .success:
                completion(.success(true))
            }
        }
    }

    @discardableResult
    func prepare(_ beamObject: BeamObject,
                 _ completion: @escaping (Swift.Result<BeamObjectUpload, Error>) -> Void) throws -> URLSessionDataTask? {

        let parameters = try prepareBeamObjectParameters(beamObject)

        let bodyParamsRequest = GraphqlParameters(fileName: "prepare_beam_object", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<PrepareBeamObjectUpload, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let prepareBeamObjects):
                guard let beamObjectUpload = prepareBeamObjects.beamObjectUpload else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }

                completion(.success(beamObjectUpload))
            }
        }
    }

    @discardableResult
    func prepare(_ beamObjects: [BeamObject],
                 _ completion: @escaping (Swift.Result<[BeamObjectUpload], Error>) -> Void) throws -> URLSessionDataTask? {
        let saveObjects: [BeamObject] = beamObjects.map {
            $0.copy()
        }

        let parameters = try prepareBeamObjectsParameters(saveObjects)

        let bodyParamsRequest = GraphqlParameters(fileName: "prepare_beam_objects", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<PrepareBeamObjectsUpload, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let prepareBeamObjects):
                guard let beamObjects = prepareBeamObjects.beamObjectsUpload else {
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
        if Configuration.beamObjectOnRest {
            return try deleteAllWithRest(beamObjectType: beamObjectType, completion)
        }

        return try deleteAllWithGraphQL(beamObjectType: beamObjectType, completion)
    }

    @discardableResult
    func deleteAllWithGraphQL(beamObjectType: BeamObjectObjectType? = nil,
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
    func deleteAllWithRest(beamObjectType: BeamObjectObjectType? = nil,
                           _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask {

        struct Parameters: Codable {
            let beamObjectType: String?
        }

        let parameters = Parameters(beamObjectType: beamObjectType?.rawValue)

        return try performRestRequest(path: .deleteAll,
                                      httpMethod: .delete,
                                      postParams: parameters,
                                      authenticatedCall: true,
                                      completionHandler: { (result: Swift.Result<DeleteAllBeamObjects, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(true))
            }
        })
    }

    @discardableResult
    func fetchAll(receivedAtAfter: Date? = nil,
                  ids: [UUID]? = nil,
                  beamObjectType: String? = nil,
                  skipDeleted: Bool? = false,
                  raisePrivateKeyError: Bool = false,
                  _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        if Configuration.beamObjectOnRest {
            if Configuration.beamObjectDataOnSeparateCall {
                return try fetchAllWithDataUrlWithRest(receivedAtAfter: receivedAtAfter,
                                                       ids: ids,
                                                       beamObjectType: beamObjectType,
                                                       skipDeleted: skipDeleted,
                                                       raisePrivateKeyError: raisePrivateKeyError,
                                                       completion)
            }

            return try fetchAllWithRest(receivedAtAfter: receivedAtAfter,
                                        ids: ids,
                                        beamObjectType: beamObjectType,
                                        skipDeleted: skipDeleted,
                                        raisePrivateKeyError: raisePrivateKeyError,
                                        completion)
        }

        if Configuration.beamObjectDataOnSeparateCall {
            return try fetchAllWithDataUrlWithGraphQL(receivedAtAfter: receivedAtAfter,
                                                      ids: ids,
                                                      beamObjectType: beamObjectType,
                                                      skipDeleted: skipDeleted,
                                                      raisePrivateKeyError: raisePrivateKeyError,
                                                      completion)
        }

        return try fetchAllWithGraphQL(receivedAtAfter: receivedAtAfter,
                                       ids: ids,
                                       beamObjectType: beamObjectType,
                                       skipDeleted: skipDeleted,
                                       raisePrivateKeyError: raisePrivateKeyError,
                                       completion)

    }

    @discardableResult
    func fetchAllWithGraphQL(receivedAtAfter: Date? = nil,
                             ids: [UUID]? = nil,
                             beamObjectType: String? = nil,
                             skipDeleted: Bool? = false,
                             raisePrivateKeyError: Bool = false,
                             _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType,
                                               skipDeleted: skipDeleted)

        return try fetchAllWithFile("beam_objects", parameters, raisePrivateKeyError: raisePrivateKeyError, completion)
    }

    func fetchAllWithRest(fields: String = "id,createdAt,updatedAt,deletedAt,receivedAt,data,type,checksum,privateKeySignature",
                          receivedAtAfter: Date? = nil,
                          ids: [UUID]? = nil,
                          beamObjectType: String? = nil,
                          skipDeleted: Bool? = false,
                          raisePrivateKeyError: Bool = false,
                          _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        struct Parameters: Codable {
            let fields: String?
            let ids: [String]?
            let beamObjectType: String?
            let filterDeleted: Bool?
            let receivedAtAfter: String?
        }

        let parameters = Parameters(
            fields: fields,
            ids: ids?.map { $0.uuidString.lowercased() },
            beamObjectType: beamObjectType,
            filterDeleted: skipDeleted,
            receivedAtAfter: receivedAtAfter?.iso8601withFractionalSeconds
        )

        return try fetchAllWithRest(fields, parameters, raisePrivateKeyError: raisePrivateKeyError, completion)
    }

    @discardableResult
    func fetchAllWithDataUrl(receivedAtAfter: Date? = nil,
                             ids: [UUID]? = nil,
                             beamObjectType: String? = nil,
                             skipDeleted: Bool? = false,
                             raisePrivateKeyError: Bool = false,
                             _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        if Configuration.beamObjectOnRest {
            return try fetchAllWithDataUrlWithRest(receivedAtAfter: receivedAtAfter,
                                                   ids: ids,
                                                   beamObjectType: beamObjectType,
                                                   skipDeleted: skipDeleted,
                                                   raisePrivateKeyError: raisePrivateKeyError, completion)
        }

        return try fetchAllWithDataUrlWithGraphQL(receivedAtAfter: receivedAtAfter,
                                                  ids: ids,
                                                  beamObjectType: beamObjectType,
                                                  skipDeleted: skipDeleted,
                                                  raisePrivateKeyError: raisePrivateKeyError, completion)
    }

    @discardableResult
    func fetchAllWithDataUrlWithGraphQL(receivedAtAfter: Date? = nil,
                                        ids: [UUID]? = nil,
                                        beamObjectType: String? = nil,
                                        skipDeleted: Bool? = false,
                                        raisePrivateKeyError: Bool = false,
                                        _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType,
                                               skipDeleted: skipDeleted)

        return try fetchAllWithFile("beam_objects_data_url", parameters, raisePrivateKeyError: raisePrivateKeyError, completion)
    }

    @discardableResult
    func fetchAllWithDataUrlWithRest(receivedAtAfter: Date? = nil,
                                     ids: [UUID]? = nil,
                                     beamObjectType: String? = nil,
                                     skipDeleted: Bool? = false,
                                     raisePrivateKeyError: Bool = false,
                                     _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {

        try fetchAllWithRest(fields: "id,checksum,createdAt,updatedAt,deletedAt,receivedAt,data,dataUrl,type,checksum,privateKeySignature",
                             receivedAtAfter: receivedAtAfter,
                             ids: ids,
                             beamObjectType: beamObjectType,
                             skipDeleted: skipDeleted,
                             raisePrivateKeyError: raisePrivateKeyError,
                             completion)
    }

    @discardableResult
    func fetchAllChecksums(receivedAtAfter: Date? = nil,
                           ids: [UUID]? = nil,
                           beamObjectType: String? = nil,
                           skipDeleted: Bool? = false,
                           raisePrivateKeyError: Bool = false,
                           _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {

        if Configuration.beamObjectOnRest {
            return try fetchAllChecksumsWithRest(receivedAtAfter: receivedAtAfter,
                                                 ids: ids,
                                                 beamObjectType: beamObjectType,
                                                 skipDeleted: skipDeleted,
                                                 raisePrivateKeyError: raisePrivateKeyError,
                                                 completion)
        }

        return try fetchAllChecksumsWithGraphQL(receivedAtAfter: receivedAtAfter,
                                                ids: ids,
                                                beamObjectType: beamObjectType,
                                                skipDeleted: skipDeleted,
                                                raisePrivateKeyError: raisePrivateKeyError,
                                                completion)
    }

    @discardableResult
    func fetchAllChecksumsWithGraphQL(receivedAtAfter: Date? = nil,
                                      ids: [UUID]? = nil,
                                      beamObjectType: String? = nil,
                                      skipDeleted: Bool? = false,
                                      raisePrivateKeyError: Bool = false,
                                      _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType,
                                               skipDeleted: skipDeleted)

        return try fetchAllWithFile("beam_object_checksums", parameters, raisePrivateKeyError: raisePrivateKeyError, completion)
    }

    @discardableResult
    func fetchAllChecksumsWithRest(receivedAtAfter: Date? = nil,
                                   ids: [UUID]? = nil,
                                   beamObjectType: String? = nil,
                                   skipDeleted: Bool? = false,
                                   raisePrivateKeyError: Bool = false,
                                   _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {
         try fetchAllWithRest(fields: "id,type,checksum",
                              receivedAtAfter: receivedAtAfter,
                              ids: ids,
                              beamObjectType: beamObjectType,
                              skipDeleted: skipDeleted,
                              raisePrivateKeyError: raisePrivateKeyError,
                              completion)
    }

    @discardableResult
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func fetchAllWithRest<C: Codable>(_ fields: String,
                                              _ parameters: C,
                                              raisePrivateKeyError: Bool,
                                              _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> URLSessionDataTask {

        return try performRestRequest(path: .fetchAll,
                                      postParams: parameters,
                                      authenticatedCall: true,
                                      completionHandler: { (result: Swift.Result<UserMe, Error>) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let me):
                guard let beamObjects = me.beamObjects else {
                    completion(.failure(APIRequestError.parserError))
                    return
                }

                self.parseBeamObjects(beamObjects: beamObjects,
                                      raisePrivateKeyError: raisePrivateKeyError,
                                      completion)
            }
        })
    }

    @discardableResult
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func fetchAllWithFile<T: Encodable>(_ filename: String,
                                                _ parameters: T,
                                                raisePrivateKeyError: Bool,
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

                self.parseBeamObjects(beamObjects: beamObjects,
                                      raisePrivateKeyError: raisePrivateKeyError,
                                      completion)
            }
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func parseBeamObjects(beamObjects: [BeamObject], raisePrivateKeyError: Bool, _ completion: @escaping (Swift.Result<[BeamObject], Error>) -> Void) {
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
                var invalidObjects = [BeamObject]()

                let localTimer = BeamDate.now
                let decryptedObjects: [BeamObject] = try beamObjects.compactMap {
                    do {
                        try $0.decrypt()
                        try $0.setTimestamps()
                        return $0
                    } catch EncryptionManagerError.authenticationFailure {
                        Logger.shared.logError("Can't decrypt \($0)", category: .beamObjectNetwork)
                    } catch BeamObject.BeamObjectError.differentEncryptionKey {
                        let privateKeySignature = try EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString().SHA256()
                        invalidObjects.append($0)
                        Logger.shared.logError("Can't decrypt beam object, private key \($0.privateKeySignature ?? "-") unavailable. Current private key: \(privateKeySignature).", category: .beamObjectNetwork)
                    }

                    return nil
                }

                Logger.shared.logDebug("Decrypted \(decryptedObjects.count) objects", category: .beamObject, localTimer: localTimer)

                if decryptedObjects.count < beamObjects.count && raisePrivateKeyError {
                    completion(.failure(BeamObjectRequestError.privateKeyError(validObjects: decryptedObjects, invalidObjects: invalidObjects)))
                } else {
                    completion(.success(decryptedObjects))
                }
            } catch {
                // Will catch anything but encryption errors
                completion(.failure(error))
                return
            }
        }

        // I used this during debug
//        beamObjects.forEach {
//            // Both dataUrl and data nil is weird, shouldn't happen
//            assert($0.dataUrl != nil || $0.data != nil)
//        }

        guard !beamObjects.compactMap({ $0.dataUrl }).isEmpty else {
            callback()
            return
        }

        let group = DispatchGroup()
        let lock = DispatchSemaphore(value: 1)

        // TODO: are all those fetches optimized, what happens when we have 1,000 objects?
        // Could we limit the amount of parallel calls? Can we stream multiple into the same HTTP Request?

        // Sorted is necessary to avoid issues during tests with Vinyl and returning different content for different objects
        let sortedBeamObjects: [BeamObject] = {
            if Configuration.env == .test {
                return beamObjects.sorted(by: { $0.id.uuidString > $1.id.uuidString })
            } else {
                return beamObjects
            }
        }()

        for beamObject in sortedBeamObjects {
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
            if Configuration.env == .test {
                usleep(100000) // 0.1s
            }
        }

        group.wait()

        callback()
    }

    @discardableResult
    func fetch<T: BeamObjectProtocol> (object: T,
                                       _ completionHandler: @escaping (Swift.Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchWithFile(filename: Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object",
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
        case noData
        case privateKeyError(validObjects: [BeamObject], invalidObjects: [BeamObject])
    }

    @discardableResult
    public func fetchDataFromUrl(urlString: String,
                                 _ completionHandler: @escaping (Result<Data, Error>) -> Void) throws -> URLSessionDataTask {

        guard let url = URL(string: urlString) else {
             throw BeamObjectRequestError.malformattedURL
        }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)"
        ]

        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = BeamURLSession.shared
        let localTimer = BeamDate.now
        let task = session.dataTask(with: request) { (data, response, error) -> Void in
            #if DEBUG
            // This is not an API call on our servers but since it's tightly coupled, I still store analytics there
            APIRequest.networkCallFilesSemaphore.wait()
            APIRequest.networkCallFiles.append("direct_download")
            APIRequest.networkCallFilesSemaphore.signal()
            #endif

            APIRequest.callsCount += 1

            // I only enable those log manually, they're very verbose!
            Logger.shared.logDebug("[\(data?.count.byteSize ?? "-")] \((response as? HTTPURLResponse)?.statusCode ?? 0) download \(urlString)",
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

    @discardableResult
    func sendDataToUrl(urlString: String,
                       putHeaders: [String: String],
                       data: Data,
                       _ completionHandler: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask {
        guard let url = URL(string: urlString) else {
             throw BeamObjectRequestError.malformattedURL
        }
        var request = URLRequest(url: url)

        var headers = putHeaders
        headers["User-Agent"] = "Beam client, \(Information.appVersionAndBuild)"
        headers["Content-Length"] = String(data.count)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.allHTTPHeaderFields = headers

        let session = BeamURLSession.shared
        let localTimer = BeamDate.now

        let task = session.dataTask(with: request) { (responseData, response, error) -> Void in
            #if DEBUG
            // This is not an API call on our servers but since it's tightly coupled, I still store analytics there
            APIRequest.networkCallFilesSemaphore.wait()
            APIRequest.networkCallFiles.append("direct_upload")
            APIRequest.networkCallFilesSemaphore.signal()
            #endif

            APIRequest.callsCount += 1

            // I only enable those log manually, they're very verbose!
            Logger.shared.logDebug("[\(data.count.byteSize)] \((response as? HTTPURLResponse)?.statusCode ?? 0) upload \(urlString)",
                                   category: .network,
                                   localTimer: localTimer)

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(error ?? BeamObjectRequestError.not200))
                return
            }

            /*
             S3 direct upload returns 0 byte for `data` (now named `_`), Vinyl will not store it at all. Don't match on it as:

             `data != nil == true` on the first call, but false when going through Vinyl
             */

            guard [200, 204].contains(httpResponse.statusCode) else {
                Logger.shared.logError("Error while uploading data: \(httpResponse.statusCode)", category: .network)
                if let responseData = responseData, let responseString = responseData.asString {
                    dump(responseString)
                }

                Logger.shared.logDebug("Sent headers: \(headers)", category: .network)
                completionHandler(.failure(error ?? BeamObjectRequestError.not200))

                return
            }

            completionHandler(.success(true))
        }

        task.resume()
        return task
    }

    func fetchAllObjectPrivateKeySignatures(_ completionHandler: @escaping (Swift.Result<[String], Error>) -> Void) throws {
        try fetchAllWithFile("all_objects_private_key_signatures", EmptyVariable(), raisePrivateKeyError: false) { result in
            switch result {
            case let .failure(error):
                Logger.shared.logError(error.localizedDescription, category: .network)
                completionHandler(.failure(error))
            case let .success(objects):
                let sigs = objects.compactMap { $0.privateKeySignature }
                completionHandler(.success(sigs))
            }
        }
    }
}
