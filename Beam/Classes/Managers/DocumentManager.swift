import Foundation
import CoreData
import Alamofire
import Combine

// swiftlint:disable file_length

enum NoteType: String, Codable {
    case journal
    case note
}

public struct DocumentStruct {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var data: Data
    let documentType: DocumentType
    var previousChecksum: String?
    var previousData: Data?

    var uuidString: String {
        id.uuidString.lowercased()
    }

    var previousDataString: String? {
        guard let previousData = previousData else { return nil }
        return previousData.asString
    }

    mutating func clearPreviousData() {
        previousChecksum = nil
        previousData = nil
    }

    func copy() -> DocumentStruct {
        let copy = DocumentStruct(id: id,
                                  title: title,
                                  createdAt: createdAt,
                                  updatedAt: updatedAt,
                                  deletedAt: deletedAt,
                                  data: data,
                                  documentType: documentType,
                                  previousChecksum: previousChecksum,
                                  previousData: previousData)
        return copy
    }
}

extension DocumentStruct {
    init(document: Document) {
        self.id = document.id
        self.createdAt = document.created_at
        self.updatedAt = document.updated_at
        self.title = document.title
        self.documentType = DocumentType(rawValue: document.document_type) ?? .note
        self.data = document.data ?? Data()
        self.previousData = document.beam_api_data
        self.previousChecksum = document.beam_api_data?.MD5
    }

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
        return result
    }
}

enum DocumentManagerError: Error, Equatable {
    case unresolvedConflict
    case localDocumentNotFound
}

// swiftlint:disable:next type_body_length
class DocumentManager {
    var coreDataManager: CoreDataManager
    let mainContext: NSManagedObjectContext
    let documentRequest = DocumentRequest()

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        self.mainContext = self.coreDataManager.mainContext

        observeCoredataNotification()
    }

    // MARK: -
    // MARK: Coredata Updates
    private var cancellables = [AnyCancellable]()
    private func observeCoredataNotification() {
        NotificationCenter.default
            .publisher(for: Notification.Name.NSManagedObjectContextObjectsDidChange)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.printObjects(notification)
            }
            .store(in: &cancellables)
    }

    /// Use this to have updates when the underlaying CD object `Document` changes
    func onDocumentChange(_ documentStruct: DocumentStruct, completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        let cancellable = NotificationCenter.default
            .publisher(for: Notification.Name.NSManagedObjectContextObjectsDidChange)
            .compactMap({ self.notificationsToDocuments($0) })
            .filter({ $0.map({ $0.id }).contains(documentStruct.id) })
            .sink { documents in
                for document in documents where document.id == documentStruct.id {
                    Logger.shared.logDebug("onDocumentChange: \(document.title)", category: .coredata)
                    Logger.shared.logDebug(document.data?.asString ?? "-", category: .documentDebug)

                    let keys = Array(document.changedValues().keys)
                    guard keys != ["beam_api_data"] else {
                        return
                    }

                    completionHandler(DocumentStruct(document: document))
                }
            }
        return cancellable
    }

    private func notificationsToDocuments(_ notification: Notification) -> [Document] {
        if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            return updatedObjects.compactMap { $0 as? Document }
        }

        return []
    }

    @objc func managedObjectContextObjectsDidChange(_ notification: Notification) {
        printObjects(notification)
    }

    private func printObjectsFromNotification(_ notification: Notification, _ keyPath: String) {
        if let objects = notification.userInfo?[keyPath] as? Set<NSManagedObject>, !objects.isEmpty {
            let titles = objects.compactMap { object in
                (object as? Document)?.title
            }
            Logger.shared.logDebug("\(Unmanaged.passUnretained(self).toOpaque()) \(keyPath) \(objects.count) CD objects. Titles: \(titles)", category: .coredataDebug)
            if objects.count != titles.count {
                Logger.shared.logDebug(String(describing: objects), category: .coredataDebug)
            }
        }
    }

    func printObjects(_ notification: Notification) {
        // let context = notification.object as? NSManagedObjectContext

        printObjectsFromNotification(notification, NSInsertedObjectsKey)
        printObjectsFromNotification(notification, NSUpdatedObjectsKey)
        printObjectsFromNotification(notification, NSDeletedObjectsKey)
        printObjectsFromNotification(notification, NSRefreshedObjectsKey)
        printObjectsFromNotification(notification, NSInvalidatedObjectsKey)

        if let areInvalidatedAllObjects = notification.userInfo?[NSInvalidatedAllObjectsKey] as? Bool {
            Logger.shared.logDebug("All objects are invalidated: \(areInvalidatedAllObjects)", category: .coredata)
        }
    }

    // MARK: -
    // MARK: CoreData Saving

    /// `saveDocument` will save locally in CoreData then call the completion handler
    /// If the user is authenticated, and network is enabled, it will also call the BeamAPI (async) to save the document remotely
    /// but will not trigger the completion handler. If the network callbacks updates the coredata object, it is expected the
    /// updates to be fetched through `onDocumentUpdate`
    func saveDocument(_ documentStruct: DocumentStruct, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(documentStruct.title)", category: .document)
        Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

        coreDataManager.backgroundContext.perform {
            let context = self.coreDataManager.backgroundContext
            let document = Document.fetchOrCreateWithId(context, documentStruct.id)
            self.updateDocumentWithDocumentStruct(document, documentStruct)

            do {
                try self.checkValidations(context, document)
            } catch {
                completion?(.failure(error))
                return
            }

            Self.saveContext(context: context) { result in
                do {
                    _ = try result.get()
                } catch {
                    completion?(.failure(error))
                    return
                }
            }

            // If not authenticated, we don't need to send to BeamAPI
            if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
                // We only want one network call per document ID, to avoid overlapping
                self.blockDocumentNetworkCall(document.id)

                // We want to fetch back the document, to update it's previousChecksum
                context.refresh(document, mergeChanges: false)
                self.saveDocumentStructOnAPI(DocumentStruct(document: document)) { _ in
                    Self.saveDataRequests.removeValue(forKey: documentStruct.id)
                    self.signalDocumentNetworkCall(document.id)
                }
            }

            completion?(.success(true))
        }
    }

    func clearNetworkCalls() {
        Self.saveDataRequestsSemaphore.wait()
        for (_, request) in Self.saveDataRequests {
            request?.cancel()
        }
        Self.saveDataRequestsSemaphore.signal()
    }

    static let serialQueue = DispatchQueue(label: "co.beamapp.documentManager")

    private func blockDocumentNetworkCall(_ id: UUID) {
        Self.serialQueue.sync {
            Self.saveSemaphores[id]?.wait()
            Self.saveSemaphores[id] = Self.saveSemaphores[id] ?? DispatchSemaphore(value: 0)
        }
    }
    private func signalDocumentNetworkCall(_ id: UUID) {
        Self.saveSemaphores[id]?.signal()
    }

    // MARK: -
    // MARK: Network Saving
    private static let saveDataRequestsSemaphore = DispatchSemaphore(value: 1)
    private static var saveDataRequests: [UUID: DataRequest?] = [:]
    private static var saveSemaphores: [UUID: DispatchSemaphore] = [:]

    internal func saveDocumentStructOnAPI(_ documentStruct: DocumentStruct,
                                          _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }
        Self.saveDataRequestsSemaphore.wait()
        Self.saveDataRequests[documentStruct.id]??.cancel()
        Self.saveDataRequests[documentStruct.id] = documentRequest.saveDocument(documentStruct.asApiType()) { result in
            switch result {
            case .failure(let error):
                self.saveDocumentStructOnAPIFailure(documentStruct, error, completion)
            case .success:
                self.saveDocumentStructOnAPISuccess(documentStruct, completion)
            }
        }
        Self.saveDataRequestsSemaphore.signal()
    }

    private func saveDocumentStructOnAPIFailure(_ documentStruct: DocumentStruct,
                                                _ error: Error,
                                                _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // We only manage conflicts, all other network errors are dispatched
        guard case APIRequestError.documentConflict = error else {
            completion?(.failure(error))
            return
        }

        Logger.shared.logDebug("Server rejected our update \(documentStruct.title): \(documentStruct.previousChecksum ?? "-")", category: .network)
        Logger.shared.logDebug("PreviousData: \(documentStruct.previousDataString ?? "-")", category: .documentDebug)

        fetchAndMergeDocument(documentStruct) { result in
            switch result {
            case .success:
                // Conflict was resolved
                completion?(.success(true))
                return
            case .failure:
                // Saving the document on the API gave a conflict we were not able to fix
                NotificationCenter.default.post(name: .apiDocumentConflict,
                                                object: documentStruct)

                // TODO: enforcing server overwrite for now by disabling checksum, but we should display a
                // conflict window and suggest to the user to keep a version or another, and not overwrite
                // existing data
                var clearedDocumentStruct = documentStruct.copy()
                clearedDocumentStruct.clearPreviousData()
                self.saveDocumentStructOnAPI(clearedDocumentStruct, completion)
            }
        }
    }

    private func saveDocumentStructOnAPISuccess(_ documentStruct: DocumentStruct,
                                                _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let documentCoreData = Document.fetchWithId(context, documentStruct.id) else {
                completion?(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }

            // We save the remote stored version of the document, to know if we have local changes later
            // `beam_api_data` stores the last version we sent to the API
            documentCoreData.beam_api_data = documentStruct.data
            Self.saveContext(context: context, completion: completion)
        }
    }

    // MARK: -
    // MARK: CoreData Create
    func createAsync(title: String, completion: ((DocumentStruct?) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.create(context, title: title)
            do {
                try self.checkValidations(context, document)

                Self.saveContext(context: context)
                completion?(self.parseDocumentBody(document))
            } catch {
                completion?(nil)
            }
        }
    }

    func create(title: String) -> DocumentStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DocumentStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.create(context, title: title)

            do {
                try self.checkValidations(context, document)

                result = self.parseDocumentBody( document)
                Self.saveContext(context: context)
                semaphore.signal()
            } catch {
            }
        }

        semaphore.wait()

        return result
    }

    // MARK: -
    // MARK: CoreData Load
    func loadDocumentById(id: UUID) -> DocumentStruct? {
        guard let document = Document.fetchWithId(mainContext, id) else { return nil }

        return parseDocumentBody(document)
    }

    func fetchOrCreateAsync(title: String, completion: ((DocumentStruct?) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.fetchOrCreateWithTitle(context, title)
            do {
                try self.checkValidations(context, document)

                Self.saveContext(context: context)
                completion?(self.parseDocumentBody(document))
            } catch {
                completion?(nil)
            }
        }
    }

    func fetchOrCreate(title: String) -> DocumentStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DocumentStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.fetchOrCreateWithTitle(context, title)
            do {
                try self.checkValidations(context, document)

                result = self.parseDocumentBody( document)
                Self.saveContext(context: context)
                semaphore.signal()
            } catch {
            }
        }

        semaphore.wait()
        return result
    }

    func allDocumentsTitles() -> [String] {
        if Thread.isMainThread {
            return Document.fetchAllNames(context: mainContext)
        } else {
            var result: [String] = []
            let context = coreDataManager.persistentContainer.newBackgroundContext()
            context.performAndWait {
                result = Document.fetchAllNames(context: context)
            }
            return result
        }
    }

    func loadDocByTitleInBg(title: String) -> DocumentStruct? {
        var result: DocumentStruct?
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        context.performAndWait {
            result = loadDocumentByTitle(title: title, context: context)
        }
        return result
    }

    func loadDocumentByTitle(title: String, context: NSManagedObjectContext? = nil) -> DocumentStruct? {
        guard let document = Document.fetchWithTitle(context ?? mainContext, title) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentsWithType(type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [DocumentStruct] {
        return Document.fetchWithTypeAndLimit(context: mainContext, type.rawValue, limit, fetchOffset).compactMap { (document) -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func countDocumentsWithType(type: DocumentType) -> Int {
        return Document.countWithPredicate(mainContext, NSPredicate(format: "document_type = %ld", type.rawValue))
    }

    func documentsWithTitleMatch(title: String) -> [DocumentStruct] {
        return Document.fetchAllWithTitleMatch(mainContext, title).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func documentsWithLimitTitleMatch(title: String, limit: Int = 4) -> [DocumentStruct] {
        return Document.fetchAllWithLimitedTitleMatch(mainContext, title, limit).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func loadAllDocumentsWithLimit(_ limit: Int = 4) -> [DocumentStruct] {
        return Document.fetchAllWithLimitResult(mainContext, limit).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func loadDocuments() -> [DocumentStruct] {
        return Document.fetchAll(context: mainContext).compactMap { document in
            parseDocumentBody(document)
        }
    }

    private func parseDocumentBody(_ document: Document) -> DocumentStruct {
        return DocumentStruct(id: document.id,
                              title: document.title,
                              createdAt: document.created_at,
                              updatedAt: document.updated_at,
                              deletedAt: document.deleted_at,
                              data: document.data ?? Data(),
                              documentType: DocumentType(rawValue: document.document_type) ?? DocumentType.note,
                              previousChecksum: document.beam_api_data?.MD5,
                              previousData: document.beam_api_data)
    }

    // MARK: -
    // MARK: CoreData Deletes
    func deleteDocument(id: UUID, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchWithId(context, id)
            document?.delete(context)

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                completion?(.success(false))
                return
            }

            self.blockDocumentNetworkCall(id)

            Self.saveDataRequestsSemaphore.wait()
            Self.saveDataRequests[id]??.cancel()
            Self.saveDataRequests[id] = self.documentRequest.deleteDocument(id.uuidString.lowercased()) { result in
                self.signalDocumentNetworkCall(id)

                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
            Self.saveDataRequestsSemaphore.signal()
        }
    }

    // MARK: -
    // MARK: Network refresh
    /// Fetch all remote documents from API
    func refreshDocuments(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        documentRequest.fetchDocuments { result in
            switch result {
            case .failure(let error):
                completion?(.failure(error))
            case .success(let documentAPITypes):
                self.refreshDocumentsSuccess(documentAPITypes, completion)
            }
        }
    }

    private func refreshDocumentsSuccess(_ documentAPITypes: [DocumentAPIType],
                                         _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            var errors: Bool = false
            var remoteDocumentsIds: [UUID] = []
            for documentAPIType in documentAPITypes {
                guard let uuid = documentAPIType.id?.uuid else {
                    errors = true
                    Logger.shared.logError("\(documentAPIType) has no id", category: .network)
                    continue
                }
                remoteDocumentsIds.append(uuid)

                let document = Document.fetchOrCreateWithId(context, uuid)

                // Making sure we had no local updates, and simply overwritten the local version
                if !self.updateDocumentWithDocumentAPIType(document, documentAPIType) {
                    errors = true
                    Logger.shared.logError("\(documentAPIType) has local changes and couldn't be merged",
                                           category: .network)

                    continue
                }
            }

            // Deleting local documents we haven't found remotely
            self.deleteNonExistingIds(context, remoteDocumentsIds)

            if errors {
                Self.saveContext(context: context)
                completion?(.failure(DocumentManagerError.unresolvedConflict))
            } else {
                Self.saveContext(context: context, completion: completion)
            }
        }
    }

    /// Must be called within the context thread
    private func deleteNonExistingIds(_ context: NSManagedObjectContext, _ remoteDocumentsIds: [UUID]) {
        // TODO: We could optimize using an `UPDATE` statement instead of loading all documents but I don't expect
        // this to ever have a lot of them
        let documents = Document.fetchAllWithLimit(context: context,
                                                   NSPredicate(format: "NOT id IN %@", remoteDocumentsIds))
        for document in documents {
            Logger.shared.logDebug("Marking \(document.title) as deleted", category: .document)
            document.deleted_at = BeamDate.now
        }
    }

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    // swiftlint:disable:next function_body_length
    // swiftlint:disable:next cyclomatic_complexity
    func refreshDocument(_ documentStruct: DocumentStruct, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        self.blockDocumentNetworkCall(documentStruct.id)

        Self.saveDataRequestsSemaphore.wait()
        Self.saveDataRequests[documentStruct.id]??.cancel()
        Self.saveDataRequests[documentStruct.id] = documentRequest.fetchDocumentUpdatedAt(documentStruct.uuidString) { result in
            self.signalDocumentNetworkCall(documentStruct.id)

            switch result {
            case .failure(let error):
                if (error as? AFError)?.responseCode == 404 {
                    self.deleteLocalDocument(documentStruct)
                }

                completion?(.failure(error))
            case .success(let documentType):
                // If the document we fetched from the API has a lower updatedAt, we can skip it
                guard let updatedAt = documentType.updatedAt, updatedAt > documentStruct.updatedAt else {
                    completion?(.success(false))
                    return
                }
                self.refreshDocumentSuccess(documentStruct, documentType, completion)
            }
        }
        Self.saveDataRequestsSemaphore.signal()
    }

    private func refreshDocumentSuccess(_ documentStruct: DocumentStruct,
                                        _ documentType: DocumentAPIType,
                                        _ completion: ((Result<Bool, Error>) -> Void)? = nil) {

        documentRequest.fetchDocument(documentStruct.uuidString) { result in
            switch result {
            case .failure(let error):
                // Fetched returned 404, it doesn't exist anymore.
                if (error as? AFError)?.responseCode == 404 {
                    self.deleteLocalDocument(documentStruct)
                }
                completion?(.failure(error))
            case .success(let documentType):
                self.refreshDocumentSuccessSuccess(documentStruct, documentType, completion)
            }
        }
    }

    private func refreshDocumentSuccessSuccess(_ documentStruct: DocumentStruct,
                                               _ documentType: DocumentAPIType,
                                               _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // Saving the remote version locally
        coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let document = Document.fetchWithId(context, documentStruct.id) else {
                completion?(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }

            // Making sure we had no local updates, and simply overwritten the local version
            if !self.updateDocumentWithDocumentAPIType(document, documentType) {
                completion?(.failure(DocumentManagerError.unresolvedConflict))
                return
            }

            Self.saveContext(context: context, completion: completion)
        }
    }

    private func deleteLocalDocument(_ documentStruct: DocumentStruct) {
        self.coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let document = Document.fetchWithId(context, documentStruct.id) else {
                return
            }

            document.deleted_at = Date()

            Self.saveContext(context: context)
        }
    }

    /// Update local coredata instance with data we fetched remotely
    private func updateDocumentWithDocumentAPIType(_ document: Document, _ documentType: DocumentAPIType) -> Bool {
        // We have local changes we didn't send to the API yet, need for merge
        if document.hasLocalChanges {
            let merged = mergeDocumentWithNewData(document, documentType)
            if !merged { return false }
        } else if let stringData = documentType.data {
            document.data = stringData.asData
            document.beam_api_data = stringData.asData
        }

        document.title = documentType.title ?? document.title
        document.created_at = documentType.createdAt ?? document.created_at
        document.updated_at = documentType.updatedAt ?? document.updated_at
        document.deleted_at = documentType.deletedAt ?? document.deleted_at
        document.document_type = documentType.documentType ?? document.document_type

        return true
    }

    private func updateDocumentWithDocumentStruct(_ document: Document, _ documentStruct: DocumentStruct) {
        document.data = documentStruct.data
        document.title = documentStruct.title
        document.document_type = documentStruct.documentType.rawValue
        document.updated_at = BeamDate.now
        document.deleted_at = documentStruct.deletedAt
    }

    // MARK: -
    // MARK: Merge and conflict management

    /// When sending a new local version of a document to the API and the API rejects it,
    /// we want to merge the new remote version, with our updated local version
    private func fetchAndMergeDocument(_ document: DocumentStruct,
                                       _ completion: @escaping (Result<Bool, Error>) -> Void) {
        documentRequest.fetchDocument(document.uuidString) { [weak self] result in
            guard let self = self else {
                completion(.failure(DocumentManagerError.unresolvedConflict))
                return
            }

            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let documentAPIType):
                self.manageDocumentConflictMerge(document, documentAPIType, completion)
            }
        }
    }

    // When having a conflict between versions
    private func manageDocumentConflictMerge(_ document: DocumentStruct,
                                             _ remoteDocument: DocumentAPIType,
                                             _ completion: @escaping (Result<Bool, Error>) -> Void) {

        guard let beam_api_data = document.previousData,
              let remoteDataString = remoteDocument.data,
              let remoteData = remoteDocument.data?.asData else {
            completion(.failure(DocumentManagerError.unresolvedConflict))
            return
        }

        let localData = document.data

        Logger.shared.logDebug("ancestor:", category: .documentMerge)
        Logger.shared.logDebug(beam_api_data.asString ?? "--", category: .documentMerge)

        Logger.shared.logDebug("local:", category: .documentMerge)
        Logger.shared.logDebug(localData.asString ?? "--", category: .documentMerge)

        Logger.shared.logDebug("Remote:", category: .documentMerge)
        Logger.shared.logDebug(remoteData.asString ?? "--", category: .documentMerge)

        let data = BeamElement.threeWayMerge(ancestor: beam_api_data,
                                             input1: localData,
                                             input2: remoteData)

        guard let newData = data else {
            Logger.shared.logDebug("Couldn't merge the two versions for: \(document.title)", category: .documentMerge)
            Logger.shared.logDebug(prettyFirstDifferenceBetweenStrings(NSString(string: localData.asString ?? ""),
                                                                       NSString(string: remoteDataString)) as String,
                                   category: .documentMerge)
            completion(.failure(DocumentManagerError.unresolvedConflict))
            return
        }

        Logger.shared.logDebug("Diff:",
                               category: .documentMerge)
        Logger.shared.logDebug(prettyFirstDifferenceBetweenStrings(NSString(string: localData.asString ?? ""),
                                                                   NSString(string: remoteDataString)) as String,
                               category: .documentMerge)

        Logger.shared.logDebug("Merged:", category: .documentDebug)
        Logger.shared.logDebug(newData.asString ?? "--", category: .documentDebug)

        Logger.shared.logDebug("manageDocumentConflict: Merged the two versions together, saving on API for \(document.title)",
                               category: .documentMerge)

        coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let documentCoreData = Document.fetchWithId(context, document.id) else {
                completion(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }
            documentCoreData.data = newData
            documentCoreData.beam_api_data = remoteData

            Self.saveContext(context: context, completion: completion)

            self.saveDocumentStructOnAPI(DocumentStruct(document: documentCoreData))
        }
    }

    /// Update local coredata instance with data we fetched remotely, we detected the need for a merge between both versions
    private func mergeWithLocalChanges(_ document: Document, _ input2: Data) -> Bool {
        guard let beam_api_data = document.beam_api_data,
              let input1 = document.data else {
            return false
        }

        let data = BeamElement.threeWayMerge(ancestor: beam_api_data,
                                             input1: input1,
                                             input2: input2)

        guard let newData = data else {
            Logger.shared.logDebug("Could not Merge Local changes when refreshing remote -> local", category: .documentDebug)
            Logger.shared.logDebug("Ancestor:\n\(beam_api_data.asString ?? "-")", category: .documentDebug)
            Logger.shared.logDebug("Input1:\n\(input1.asString ?? "-")", category: .documentDebug)
            Logger.shared.logDebug("Input2:\n\(input2.asString ?? "-")", category: .documentDebug)
            Logger.shared.logDebug("Diff:", category: .documentDebug)
            Logger.shared.logDebug(prettyFirstDifferenceBetweenStrings(NSString(string: input1.asString ?? ""),
                                                                       NSString(string: input2.asString ?? "")) as String,
                                   category: .documentDebug)

            return false
        }

        Logger.shared.logDebug("Merged:\n\(newData.asString ?? "-")",
                               category: .documentDebug)

        document.data = newData
        document.beam_api_data = input2
        return true
    }

    /// Update local coredata instance with data we fetched remotely, and merge both together
    private func mergeDocumentWithNewData(_ document: Document, _ documentType: DocumentAPIType) -> Bool {
        guard let data = documentType.data?.asData,
              mergeWithLocalChanges(document, data) else {
            // Local version could not be merged with remote version
            Logger.shared.logError("Document has local change but could not merge", category: .documentMerge)
            NotificationCenter.default.post(name: .apiDocumentConflict,
                                            object: DocumentStruct(document: document))
            return false
        }

        // Local version was merged with remote version
        Logger.shared.logError("Document has local change! Merged both local and remote", category: .documentMerge)
        return true
    }

    // swiftlint:disable:next cyclomatic_complexity
    func deleteAllDocuments(includedRemote: Bool = true, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        CoreDataManager.shared.destroyPersistentStore {
            CoreDataManager.shared.setup()

            guard includedRemote else {
                completion?(.success(true))
                return
            }

            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                completion?(.success(false))
                return
            }

            self.documentRequest.deleteAllDocuments { result in
                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        }
    }

    // MARK: -
    // MARK: Bulk calls
    func uploadAllDocuments(_ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            let documents = Document.fetchAll(context: context)
            let documentsArray: [DocumentAPIType] = documents.map { document in document.asApiType() }

            self.documentRequest.importDocuments(documentsArray) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .network)
                    completion?(.failure(error))
                case .success:
                    Logger.shared.logDebug("Documents imported", category: .network)
                    completion?(.success(true))
                }
            }
        }
    }

    // MARK: -
    // MARK: NSManagedObjectContext saves
    static func saveContext(context: NSManagedObjectContext, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard context.hasChanges else {
            completion?(.success(true))
            return
        }

        do {
            try CoreDataManager.save(context)
            Logger.shared.logDebug("CoreDataManager saved", category: .coredata)
            completion?(.success(true))
        } catch let error as NSError {
            switch error.code {
            case 133021:
                // Constraint conflict
                Logger.shared.logError("Couldn't save context because of a constraint: \(error)", category: .coredata)
                logConstraintConflict(error)
            case 133020:
                // Saving a version of NSManagedObject which is outdated
                Logger.shared.logError("Couldn't save context because the object is outdated and more recent in CoreData: \(error)", category: .coredata)
                logMergeConflict(error)
            default:
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
            }

            completion?(.failure(error))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func logConstraintConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSConstraintConflict] else { return }

        for conflict in conflicts {
            let conflictingDocuments: [Document] = conflict.conflictingObjects.compactMap { document in
                return document as? Document
            }
            for document in conflictingDocuments {
                Logger.shared.logError("Conflicting \(document.id), title: \(document.title), document: \(document)",
                                       category: .coredata)
            }

            if let document = conflict.databaseObject as? Document {
                Logger.shared.logError("Existing document \(document.id), title: \(document.title), document: \(document)",
                                       category: .coredata)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static private func logMergeConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSMergeConflict] else { return }

        for conflict in conflicts {
            let title = (conflict.sourceObject as? Document)?.title ?? ":( Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
        }
    }

    // MARK: -
    // MARK: Validations
    private func checkValidations(_ context: NSManagedObjectContext, _ document: Document) throws {
        try checkDuplicateTitles(context, document)
    }

    private func checkDuplicateTitles(_ context: NSManagedObjectContext, _ document: Document) throws {
        // If document is deleted, we don't need to check title uniqueness
        guard document.deleted_at == nil else { return }

        let predicate = NSPredicate(format: "title = %@ AND id != %@", document.title, document.id as CVarArg)

        if Document.countWithPredicate(context, predicate) > 0 {
            let errString = "Title is already used in another document"
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString, NSValidationObjectErrorKey: self]
            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
        }
    }
}

// swiftlint:enable file_length
