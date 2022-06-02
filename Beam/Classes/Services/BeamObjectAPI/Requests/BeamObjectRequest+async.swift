import Foundation
import BeamCore

// swiftlint:disable function_length file_length

extension BeamObjectRequest {
    @discardableResult
    func save(_ beamObject: BeamObject) async throws -> BeamObject {
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

        let _: UpdateBeamObject = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        beamObject.previousChecksum = beamObject.dataChecksum
        return beamObject
    }

    func saveInline(_ beamObject: BeamObject) async throws -> BeamObject {
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

        let updateBeamObject: UpdateBeamObject = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let beamObject = updateBeamObject.beamObject else {
            throw APIRequestError.parserError
        }
        try beamObject.decrypt()
        beamObject.previousChecksum = beamObject.dataChecksum
        return beamObject
    }

    @discardableResult
    func save(_ beamObjects: [BeamObject]) async throws -> Bool {
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

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        var parameters = UpdateBeamObjects(beamObjects: saveBeamObjects, privateKey: nil)

        if EnvironmentVariables.beamObjectSendPrivateKey {
            parameters.privateKey = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects",
                                                  variables: parameters,
                                                  files: filesUpload)

        let _: UpdateBeamObjects = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        return true
    }

    func saveInline(_ beamObjects: [BeamObject]) async throws -> Bool {
        var parameters: UpdateBeamObjects

        let saveObjects: [BeamObject] = beamObjects.map {
            $0.copy()
        }

        parameters = try saveBeamObjectsParameters(saveObjects)

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects", variables: parameters)

        let _: UpdateBeamObjects = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        return true
    }

    func prepare(_ beamObject: BeamObject) async throws -> BeamObjectUpload {

        let parameters = try prepareBeamObjectParameters(beamObject)

        let bodyParamsRequest = GraphqlParameters(fileName: "prepare_beam_object", variables: parameters)

        let prepareBeamObjects: PrepareBeamObjectUpload = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let beamObjectUpload = prepareBeamObjects.beamObjectUpload else {
            throw APIRequestError.parserError
        }
        return beamObjectUpload
    }

    func prepare(_ beamObjects: [BeamObject]) async throws -> [BeamObjectUpload ] {
        let saveObjects: [BeamObject] = beamObjects.map {
            $0.copy()
        }

        let parameters = try prepareBeamObjectsParameters(saveObjects)

        let bodyParamsRequest = GraphqlParameters(fileName: "prepare_beam_objects", variables: parameters)

        let prepareBeamObjects: PrepareBeamObjectsUpload = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let beamObjectsUpload = prepareBeamObjects.beamObjectsUpload else {
            throw APIRequestError.parserError
        }
        return beamObjectsUpload
    }

    func delete<T: BeamObjectProtocol>(object: T) async throws  -> BeamObject {
        let parameters = BeamObjectIdParameters(id: object.beamObjectId,
                                                beamObjectType: type(of: object).beamObjectType.rawValue)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        let deleteBeamObject: DeleteBeamObject = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let object = deleteBeamObject.beamObject else {
            throw APIRequestError.parserError
        }
        return object
    }

    func delete(beamObject: BeamObject) async throws  -> BeamObject {
        let parameters = BeamObjectIdParameters(id: beamObject.id, beamObjectType: beamObject.beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        let deleteBeamObject: DeleteBeamObject = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let object = deleteBeamObject.beamObject else {
            throw APIRequestError.parserError
        }
        return object
    }

    func deleteAll(beamObjectType: BeamObjectObjectType? = nil) async throws -> Bool {
        if Configuration.beamObjectOnRest {
            return try await deleteAllWithRest(beamObjectType: beamObjectType)
        }

        return try await deleteAllWithGraphQL(beamObjectType: beamObjectType)
    }

    func deleteAllWithGraphQL(beamObjectType: BeamObjectObjectType? = nil) async throws -> Bool {
        let parameters = DeleteAllBeamObjectsParameters(beamObjectType: beamObjectType?.rawValue)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_beam_objects", variables: parameters)

        let deleteAllBeamObjects: DeleteAllBeamObjects = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard deleteAllBeamObjects.success ?? false else {
            throw APIRequestError.parserError
        }
        return true
    }

    func deleteAllWithRest(beamObjectType: BeamObjectObjectType? = nil) async throws -> Bool {

        struct Parameters: Codable {
            let beamObjectType: String?
        }

        let parameters = Parameters(beamObjectType: beamObjectType?.rawValue)

        let _: DeleteAllBeamObjects = try await performRestRequest(path: .deleteAll,
                                                                   httpMethod: .delete,
                                                                   postParams: parameters,
                                                                   authenticatedCall: true)
        return true
    }

    func fetchAll(receivedAtAfter: Date? = nil,
                  ids: [UUID]? = nil,
                  beamObjectType: String? = nil,
                  skipDeleted: Bool? = false,
                  raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        if Configuration.beamObjectOnRest {
            if Configuration.beamObjectDataOnSeparateCall {
                return try await fetchAllWithDataUrlWithRest(receivedAtAfter: receivedAtAfter,
                                                       ids: ids,
                                                       beamObjectType: beamObjectType,
                                                       skipDeleted: skipDeleted,
                                                       raisePrivateKeyError: raisePrivateKeyError)
            } else {
                return try await fetchAllWithRest(receivedAtAfter: receivedAtAfter,
                                            ids: ids,
                                            beamObjectType: beamObjectType,
                                            skipDeleted: skipDeleted,
                                            raisePrivateKeyError: raisePrivateKeyError)
            }
        } else {
            if Configuration.beamObjectDataOnSeparateCall {
                return try await fetchAllWithDataUrlWithGraphQL(receivedAtAfter: receivedAtAfter,
                                                          ids: ids,
                                                          beamObjectType: beamObjectType,
                                                          skipDeleted: skipDeleted,
                                                          raisePrivateKeyError: raisePrivateKeyError)
            } else {
                return try await fetchAllWithGraphQL(receivedAtAfter: receivedAtAfter,
                                           ids: ids,
                                           beamObjectType: beamObjectType,
                                           skipDeleted: skipDeleted,
                                           raisePrivateKeyError: raisePrivateKeyError)
            }
        }
    }

    func fetchAllWithGraphQL(receivedAtAfter: Date? = nil,
                             ids: [UUID]? = nil,
                             beamObjectType: String? = nil,
                             skipDeleted: Bool? = false,
                             raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        return try await fetchPaginatedAllWithFile(receivedAtAfter: receivedAtAfter, ids: ids, beamObjectType: beamObjectType, skipDeleted: skipDeleted, raisePrivateKeyError: raisePrivateKeyError, "paginated_beam_objects")
    }

    func fetchPaginatedAllWithFile(receivedAtAfter: Date? = nil,
                                   ids: [UUID]? = nil,
                                   beamObjectType: String? = nil,
                                   skipDeleted: Bool? = false,
                                   raisePrivateKeyError: Bool = false,
                                   _ filename: String) async throws -> [BeamObject] {

        var allBeamObjects: [BeamObject] = []
        var hasNext = true
        var after = ""
        let first = Configuration.beamObjectsPageSize
        while hasNext {
            try Task.checkCancellation()

            let parameters = PaginatedBeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                                            ids: ids,
                                                            beamObjectType: beamObjectType,
                                                            skipDeleted: skipDeleted,
                                                            first: first,
                                                            after: after,
                                                            last: nil,
                                                            before: nil)
            guard let paginatedBeamObjects = try await fetchPageWithFile(filename, parameters, raisePrivateKeyError: raisePrivateKeyError) else {
                throw APIRequestError.parserError
            }
            allBeamObjects.append(contentsOf: paginatedBeamObjects.beamObjects ?? [])
            let hasNextPage = paginatedBeamObjects.pageInfo.hasNextPage
            let endCursor = paginatedBeamObjects.pageInfo.endCursor
            let startCursor = paginatedBeamObjects.pageInfo.startCursor

            hasNext = endCursor != nil && hasNextPage && (startCursor != endCursor)

            Logger.shared.logDebug("beamObjects received so far: \(allBeamObjects.count), hasNext: \(hasNext), next cursor: \(String(describing: endCursor))", category: .network)

            if hasNext {
                after = endCursor!
            }
        }
        return allBeamObjects
    }

    func fetchAllWithRest(fields: String = "id,createdAt,updatedAt,deletedAt,receivedAt,data,type,checksum,privateKeySignature",
                          receivedAtAfter: Date? = nil,
                          ids: [UUID]? = nil,
                          beamObjectType: String? = nil,
                          skipDeleted: Bool? = false,
                          raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
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

        return try await fetchAllWithRest(fields, parameters, raisePrivateKeyError: raisePrivateKeyError)
    }

    func fetchAllWithDataUrl(receivedAtAfter: Date? = nil,
                             ids: [UUID]? = nil,
                             beamObjectType: String? = nil,
                             skipDeleted: Bool? = false,
                             raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        if Configuration.beamObjectOnRest {
            return try await fetchAllWithDataUrlWithRest(receivedAtAfter: receivedAtAfter,
                                            ids: ids,
                                            beamObjectType: beamObjectType,
                                            skipDeleted: skipDeleted,
                                            raisePrivateKeyError: raisePrivateKeyError)
        } else {
            return try await fetchAllWithDataUrlWithGraphQL(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType,
                                               skipDeleted: skipDeleted,
                                               raisePrivateKeyError: raisePrivateKeyError)
        }
    }

    func fetchAllWithDataUrlWithGraphQL(receivedAtAfter: Date? = nil,
                                        ids: [UUID]? = nil,
                                        beamObjectType: String? = nil,
                                        skipDeleted: Bool? = false,
                                        raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        return try await fetchPaginatedAllWithFile(receivedAtAfter: receivedAtAfter, ids: ids, beamObjectType: beamObjectType, skipDeleted: skipDeleted, raisePrivateKeyError: raisePrivateKeyError, "paginated_beam_objects_data_url")
    }

    func fetchAllWithDataUrlWithRest(receivedAtAfter: Date? = nil,
                                     ids: [UUID]? = nil,
                                     beamObjectType: String? = nil,
                                     skipDeleted: Bool? = false,
                                     raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {

        return try await fetchAllWithRest(fields: "id,checksum,createdAt,updatedAt,deletedAt,receivedAt,data,dataUrl,type,checksum,privateKeySignature",
                                          receivedAtAfter: receivedAtAfter,
                                          ids: ids,
                                          beamObjectType: beamObjectType,
                                          skipDeleted: skipDeleted,
                                          raisePrivateKeyError: raisePrivateKeyError)
    }

    func fetchAllChecksums(receivedAtAfter: Date? = nil,
                           ids: [UUID]? = nil,
                           beamObjectType: String? = nil,
                           skipDeleted: Bool? = false,
                           raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {

        if Configuration.beamObjectOnRest {
            return try await fetchAllChecksumsWithRest(receivedAtAfter: receivedAtAfter,
                                                       ids: ids,
                                                       beamObjectType: beamObjectType,
                                                       skipDeleted: skipDeleted,
                                                       raisePrivateKeyError: raisePrivateKeyError)

        } else {
            return try await fetchAllChecksumsWithGraphQL(receivedAtAfter: receivedAtAfter,
                                                          ids: ids,
                                                          beamObjectType: beamObjectType,
                                                          skipDeleted: skipDeleted,
                                                          raisePrivateKeyError: raisePrivateKeyError)
        }
    }

    func fetchAllChecksumsWithGraphQL(receivedAtAfter: Date? = nil,
                                      ids: [UUID]? = nil,
                                      beamObjectType: String? = nil,
                                      skipDeleted: Bool? = false,
                                      raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        return try await fetchPaginatedAllWithFile(receivedAtAfter: receivedAtAfter,
                                                   ids: ids,
                                                   beamObjectType: beamObjectType,
                                                   skipDeleted: skipDeleted, raisePrivateKeyError: raisePrivateKeyError, "paginated_beam_object_checksums")
    }

    func fetchAllChecksumsWithRest(receivedAtAfter: Date? = nil,
                                   ids: [UUID]? = nil,
                                   beamObjectType: String? = nil,
                                   skipDeleted: Bool? = false,
                                   raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        return try await fetchAllWithRest(fields: "id,type,checksum,receivedAt",
                                          receivedAtAfter: receivedAtAfter,
                                          ids: ids,
                                          beamObjectType: beamObjectType,
                                          skipDeleted: skipDeleted,
                                          raisePrivateKeyError: raisePrivateKeyError)

    }

    private func fetchAllWithRest<C: Codable>(_ fields: String,
                                              _ parameters: C,
                                              raisePrivateKeyError: Bool) async throws -> [BeamObject] {

        let userMe: UserMe = try await performRestRequest(path: .fetchAll,
                                                          postParams: parameters,
                                                          authenticatedCall: true)
        guard let beamObjects = userMe.beamObjects else {
            throw APIRequestError.parserError
        }

        return try await self.parseBeamObjects(beamObjects: beamObjects,
                                               raisePrivateKeyError: raisePrivateKeyError)
    }

    private func fetchAllWithFile<T: Encodable>(_ filename: String,
                                                _ parameters: T,
                                                raisePrivateKeyError: Bool) async throws -> [BeamObject] {
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let userMe: UserMe = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let beamObjects = userMe.beamObjects else {
            throw APIRequestError.parserError
        }

        return try await self.parseBeamObjects(beamObjects: beamObjects,
                                               raisePrivateKeyError: raisePrivateKeyError)
    }

    private func fetchPageWithFile<T: Encodable>(_ filename: String,
                                                 _ parameters: T,
                                                 raisePrivateKeyError: Bool) async throws -> PaginatedBeamObjects? {
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)
        let userMe: UserMe = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard let beamObjects = userMe.paginatedBeamObjects?.beamObjects else {
            throw APIRequestError.parserError
        }
        userMe.paginatedBeamObjects?.beamObjects = try await self.parseBeamObjects(beamObjects: beamObjects,
                                                                                   raisePrivateKeyError: raisePrivateKeyError)
        return userMe.paginatedBeamObjects
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func parseBeamObjects(beamObjects: [BeamObject], raisePrivateKeyError: Bool) async throws -> [BeamObject] {
        /*
         We cover all cases:
         - if `dataUrl` was requested, it will fetch the data in another network call, set `data` then return the object
         - if `dataUrl` wasn't requested, it just returns the object
         */

        let callback = { () -> [BeamObject] in
            /*
             When fetching all beam objects, we decrypt them if needed. We might have decryption issue
             like not having the key it was encrypted with. In such case we filter those out as the calling
             code wouldn't know what to do with it anyway.
             */
            do {
                var invalidObjects = [BeamObject]()

                if beamObjects.count > 1000 {
                    Logger.shared.logDebug("Decrypting \(beamObjects.count) objects", category: .beamObject)
                }

                // swiftlint:disable:next date_init
                let localTimer = Date()
                let decryptedObjects: [BeamObject] = try beamObjects.compactMap {
                    try Task.checkCancellation()
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

                try Task.checkCancellation()

                if decryptedObjects.count < beamObjects.count && raisePrivateKeyError {
                    throw BeamObjectRequestError.privateKeyError(validObjects: decryptedObjects, invalidObjects: invalidObjects)
                } else {
                    return decryptedObjects
                }
            } catch {
                throw error
            }
        }

        // I used this during debug
//        beamObjects.forEach {
//            // Both dataUrl and data nil is weird, shouldn't happen
//            assert($0.dataUrl != nil || $0.data != nil)
//        }

        guard !beamObjects.compactMap({ $0.dataUrl }).isEmpty else {
            return try callback()
        }

        // Sorted is necessary to avoid issues during tests with Vinyl and returning different content for different objects
        let sortedBeamObjects: [BeamObject] = {
            if Configuration.env == .test {
                return beamObjects.sorted(by: { $0.id.uuidString > $1.id.uuidString })
            } else {
                return beamObjects
            }
        }()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for beamObject in sortedBeamObjects {
                try Task.checkCancellation()
                guard let dataUrl = beamObject.dataUrl else { continue }
                group.addTask {
                    beamObject.data = try await self.fetchDataFromUrl(urlString: dataUrl)
                }
                // This code is multi-threaded, with vinyl once network calls are saved, it might take one for another
                // because not in the same order, waiting for completion before moving on next
                if Configuration.env == .test {
                    try await group.waitForAll()
                }
            }
        }
        return try callback()
    }

    func fetch<T: BeamObjectProtocol> (object: T) async throws -> BeamObject {
        let filename = Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object"
        return try await fetchWithFile(filename: filename,
                                       beamObjectID: object.beamObjectId,
                                       beamObjectType: type(of: object).beamObjectType.rawValue)
    }

    func fetch(beamObject: BeamObject) async throws -> BeamObject {
        try await fetchWithFile(filename: "beam_object",
                                beamObjectID: beamObject.id,
                                beamObjectType: beamObject.beamObjectType)
    }

    func fetchWithDataUrl(beamObject: BeamObject) async throws -> BeamObject {
        try await fetchWithFile(filename: "beam_object_data_url",
                                beamObjectID: beamObject.id,
                                beamObjectType: beamObject.beamObjectType)
    }

    func fetchWithDataUrl<T: BeamObjectProtocol>(object: T) async throws -> BeamObject {
        try await fetchWithFile(filename: "beam_object_data_url",
                                beamObjectID: object.beamObjectId,
                                beamObjectType: type(of: object).beamObjectType.rawValue)
    }

    func fetchMinimalBeamObject(beamObject: BeamObject) async throws -> BeamObject {
        try await fetchWithFile(filename: "beam_object_updated_at",
                                beamObjectID: beamObject.id,
                                beamObjectType: beamObject.beamObjectType)
    }

    func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T) async throws -> BeamObject {
        try await fetchWithFile(filename: "beam_object_updated_at",
                                beamObjectID: object.beamObjectId,
                                beamObjectType: type(of: object).beamObjectType.rawValue)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetchWithFile(filename: String,
                               beamObjectID: UUID,
                               beamObjectType: String) async throws -> BeamObject {
        let parameters = BeamObjectIdParameters(id: beamObjectID, beamObjectType: beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let fetchBeamObject: FetchBeamObject = try await performRequest(bodyParamsRequest: bodyParamsRequest)

        guard let dataUrl = fetchBeamObject.dataUrl else {
            try fetchBeamObject.decrypt()
            try fetchBeamObject.setTimestamps()
            return fetchBeamObject
        }

        let data: Data = try await self.fetchDataFromUrl(urlString: dataUrl)
        fetchBeamObject.data = data
        try fetchBeamObject.decrypt()
        try fetchBeamObject.setTimestamps()

        return fetchBeamObject
    }

    public func fetchDataFromUrl(urlString: String) async throws -> Data {

        try await withTaskCancellationHandler {
            self.cancel()
        } operation: {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try self.fetchDataFromUrl(urlString: urlString) { (result: Result<Data, Error>) in
                        switch result {
                        case .failure(let error):
                            return continuation.resume(throwing: error)
                        case .success(let res):
                            continuation.resume(returning: res)
                        }
                    }
                } catch {
                    return continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func sendDataToUrl(urlString: String,
                       putHeaders: [String: String],
                       data: Data) async throws -> Bool {
        try await withTaskCancellationHandler {
            self.cancel()
        } operation: {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try self.sendDataToUrl(urlString: urlString, putHeaders: putHeaders, data: data) { (result: Swift.Result<Bool, Error>) in
                        switch result {
                        case .failure(let error):
                            return continuation.resume(throwing: error)
                        case .success(let res):
                            continuation.resume(returning: res)
                        }
                    }
                } catch {
                    return continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAllObjectPrivateKeySignatures() async throws -> [String] {
        let objects: [BeamObject] = try await fetchAllWithFile("all_objects_private_key_signatures", EmptyVariable(), raisePrivateKeyError: false)
        let sigs = objects.compactMap { $0.privateKeySignature }
        return sigs
    }
}
