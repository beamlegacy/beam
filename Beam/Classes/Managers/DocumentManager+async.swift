import Foundation
import BeamCore

extension DocumentManager {
    /// WARNING: this will delete *ALL* documents, including from different databases.
    func deleteAll(includedRemote: Bool = true) async throws -> Bool {
        do {
            try deleteAll(databaseId: nil)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            return true
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return false
        }
        Self.cancelAllPreviousThrottledAPICall()

        return try await deleteAllFromBeamObjectAPI()
    }

    // MARK: -
    // MARK: Bulk calls
    func fetchAllOnApi() async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return false
        }

        let documents = try await self.fetchAllFromBeamObjectAPI()
        try self.receivedObjects(documents)
        return true
    }

    func saveAllOnAPI() async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return false
        }
        let documentManager = DocumentManager()
        var documents: [Document] = []
        documentManager.context.performAndWait {
            documents = (try? documentManager.fetchAll(filters: [.allDatabases, .includeDeleted])) ?? []
        }
        Logger.shared.logDebug("Uploading \(documents.count) documents", category: .documentNetwork)
        if documents.isEmpty {
            return true
        }

        // Cancel previous saves as we're saving all of the objects anyway
        Self.cancelAllPreviousThrottledAPICall()

        let documentStructs = documents.map { DocumentStruct(document: $0) }
        _ = try await self.saveOnBeamObjectsAPI(documentStructs)
        return true
    }

    // MARK: -
    // MARK: Refresh

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ documentStruct: DocumentStruct,
                 _ forced: Bool = false) async throws -> Bool {
        try await refreshFromBeamObjectAPIAndSaveLocally(documentStruct, forced)
    }

    // swiftlint:disable function_body_length
    func refreshFromBeamObjectAPIAndSaveLocally(_ documentStruct: DocumentStruct,
                                                _ forced: Bool = false) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let remoteDocumentStruct = try await refreshFromBeamObjectAPI(documentStruct, forced)
        guard let remoteDocumentStruct = remoteDocumentStruct else {
            Logger.shared.logDebug("\(documentStruct.title): remote is not more recent, skip",
                                   category: .documentNetwork)
            return false
        }

        guard remoteDocumentStruct != documentStruct else {
            Logger.shared.logDebug("\(documentStruct.title): remote is equal to stored version, skip",
                                   category: .documentNetwork)
            return false
        }

        let documentManager = DocumentManager()

        let document: Document = try documentManager.fetchOrCreate(documentStruct.id, title: documentStruct.title, deletedAt: documentStruct.deletedAt)
        Logger.shared.logDebug("Fetched \(remoteDocumentStruct.title) {\(remoteDocumentStruct.id)} with previous checksum \(try remoteDocumentStruct.checksum())",
                               category: .documentNetwork)

        if !documentManager.mergeDocumentWithNewData(document, remoteDocumentStruct) {
            document.data = remoteDocumentStruct.data
        }
        document.update(remoteDocumentStruct)
        document.version += 1

        try documentManager.checkValidations(document)

        // Once we locally saved the remote object, we want to update the local previous Checksum to
        // avoid non-existing conflicts
        try BeamObjectChecksum.savePreviousChecksum(object: remoteDocumentStruct)
        let success = try documentManager.saveContext()

        /*
         Spent *hours* on that problem. The new `DocumentManager` instance is saving the coredata object,
         but the `context` attached to `self` seems to return an old version of the coredata object unless
         we force and refresh that object manually...
         */
        context.performAndWait {
            if let localStoredDocument = try? self.fetchWithId(documentStruct.id, includeDeleted: true) {
                self.context.refresh(localStoredDocument, mergeChanges: false)

                #if DEBUG
                assert(localStoredDocument.data == document.data)
                #endif
            } else {
                assert(false)
            }
        }

        try BeamObjectChecksum.savePreviousObject(object: remoteDocumentStruct)

        #if DEBUG
        if let localStoredDocumentStruct = documentManager.loadById(id: documentStruct.id, includeDeleted: true) {
            dump(localStoredDocumentStruct)
            assert(localStoredDocumentStruct.data == document.data)
        } else {
            assert(false)
        }
        #endif

        return success
    }
}
