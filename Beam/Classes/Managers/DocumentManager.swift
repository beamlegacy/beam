import Foundation
import CoreData
import Combine
import PromiseKit
import Promises
import PMKFoundation
import BeamCore

// swiftlint:disable file_length

enum DocumentManagerError: Error, Equatable {
    case unresolvedConflict
    case localDocumentNotFound
    case idNotFound
    case operationCancelled
}

// swiftlint:disable:next type_body_length
public class DocumentManager: NSObject {
    var coreDataManager: CoreDataManager
    let mainContext: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    private let backgroundQueue = DispatchQueue.global(qos: .background)

    private let saveDocumentQueue = OperationQueue()
    private var saveOperations: [UUID: BlockOperation] = [:]
    private var saveDocumentPromiseCancels: [UUID: () -> Void] = [:]

    private static var networkRequests: [UUID: APIRequest] = [:]
    private var networkTasks: [UUID: (DispatchWorkItem, ((Swift.Result<Bool, Error>) -> Void)?)] = [:]
    private var networkTasksSemaphore = DispatchSemaphore(value: 1)

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        self.mainContext = self.coreDataManager.mainContext
        self.backgroundContext = self.coreDataManager.backgroundContext

        saveDocumentQueue.maxConcurrentOperationCount = 1

        super.init()

        // Used to debug CD issues
        //observeCoredataNotification()
    }

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
            let titles = objects.compactMap { object -> String? in
                guard let document = object as? Document else { return nil }

                return "\(document.title) version \(document.version)"
            }

            if !titles.isEmpty {
                Logger.shared.logDebug("\(Unmanaged.passUnretained(self).toOpaque()) \(keyPath) \(titles.count) Documents: \(titles)",
                                       category: .coredataDebug)
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

    func clearNetworkCalls() {
        for (_, request) in Self.networkRequests {
            request.cancel()
        }
    }

    // MARK: CoreData Load
    func loadById(id: UUID) -> DocumentStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DocumentStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            defer { semaphore.signal() }
            guard let document = try? Document.fetchWithId(context, id) else { return }

            result = parseDocumentBody(document)
        }

        semaphore.wait()
        return result
    }

    func fetchOrCreate(title: String) -> DocumentStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DocumentStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            defer { semaphore.signal() }

            let document = Document.fetchOrCreateWithTitle(context, title)

            do {
                try self.checkValidations(context, document)

                result = self.parseDocumentBody(document)
                try Self.saveContext(context: context)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .coredata)
            }
        }

        semaphore.wait()
        return result
    }

    func allDocumentsTitles() -> [String] {
        if Thread.isMainThread {
            return Document.fetchAllNames(mainContext)
        } else {
            var result: [String] = []
            let context = coreDataManager.persistentContainer.newBackgroundContext()
            context.performAndWait {
                result = Document.fetchAllNames(context)
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
        guard let document = try? Document.fetchWithTitle(context ?? mainContext, title) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentById(id: UUID, context: NSManagedObjectContext? = nil) -> DocumentStruct? {
        guard let document = try? Document.fetchWithId(context ?? mainContext, id) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentsWithType(type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [DocumentStruct] {
        do {
            return try Document.fetchWithTypeAndLimit(context: mainContext,
                                                      type.rawValue,
                                                      limit,
                                                      fetchOffset).compactMap { (document) -> DocumentStruct? in
            parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func countDocumentsWithType(type: DocumentType) -> Int {
        return Document.countWithPredicate(mainContext, NSPredicate(format: "document_type = %ld", type.rawValue))
    }

    func documentsWithTitleMatch(title: String) -> [DocumentStruct] {
        do {
            return try Document.fetchAllWithTitleMatch(mainContext, title)
                .compactMap { document -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func documentsWithLimitTitleMatch(title: String, limit: Int = 4) -> [DocumentStruct] {
        do {
            return try Document.fetchAllWithLimitedTitleMatch(mainContext, title, limit)
                .compactMap { document -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func loadAllWithLimit(_ limit: Int = 4, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [DocumentStruct] {
        do {
            return try Document.fetchAllWithLimitResult(mainContext, limit, sortDescriptors)
                .compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
                }
        } catch { return [] }
    }

    func loadAll() -> [DocumentStruct] {
        do {
            return try Document.fetchAll(mainContext).compactMap { document in
            parseDocumentBody(document)
            }
        } catch { return [] }
    }

    private func parseDocumentBody(_ document: Document) -> DocumentStruct {
        DocumentStruct(id: document.id,
                       databaseId: document.database_id,
                       title: document.title,
                       createdAt: document.created_at,
                       updatedAt: document.updated_at,
                       deletedAt: document.deleted_at,
                       data: document.data ?? Data(),
                       documentType: DocumentType(rawValue: document.document_type) ?? DocumentType.note,
                       previousData: document.beam_api_data,
                       previousChecksum: document.beam_api_checksum,
                       version: document.version,
                       isPublic: document.is_public
        )
    }

    /// Must be called within the context thread
    private func deleteNonExistingIds(_ context: NSManagedObjectContext, _ remoteDocumentsIds: [UUID]) {
        // TODO: We could optimize using an `UPDATE` statement instead of loading all documents but I don't expect
        // this to ever have a lot of them
        let documents = (try? Document.fetchAllWithLimit(context,
                                                        NSPredicate(format: "NOT id IN %@", remoteDocumentsIds))) ?? []
        for document in documents {
            Logger.shared.logDebug("Marking \(document.title) as deleted", category: .document)
            document.deleted_at = BeamDate.now
            document.version += 1
            notificationDocumentUpdate(DocumentStruct(document: document))
        }
    }

    private func saveRefresh(_ documentStruct: DocumentStruct,
                             _ documentType: DocumentAPIType) throws {

        let context = coreDataManager.persistentContainer.newBackgroundContext()
        try context.performAndWait {
            guard let document = try? Document.fetchWithId(context, documentStruct.id) else {
                throw DocumentManagerError.localDocumentNotFound
            }

            // Making sure we had no local updates, and simply overwritten the local version
            if !self.updateDocumentWithDocumentAPIType(document, documentType) {
                throw DocumentManagerError.unresolvedConflict
            }

            self.notificationDocumentUpdate(DocumentStruct(document: document))

            try Self.saveContext(context: context)
        }
    }

    private func deleteLocalDocumentAndWait(_ documentStruct: DocumentStruct) throws {
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        try context.performAndWait {
            guard let document = try? Document.fetchWithId(context, documentStruct.id) else {
                return
            }

            document.deleted_at = BeamDate.now

            try Self.saveContext(context: context)
        }
    }

    /// Update local coredata instance with data we fetched remotely
    private func updateDocumentWithDocumentAPIType(_ document: Document, _ documentApiType: DocumentAPIType) -> Bool {
        // We have local changes we didn't send to the API yet, need for merge
        if document.hasLocalChanges {
            let merged = mergeDocumentWithNewData(document, documentApiType)
            if !merged { return false }
        } else if let stringData = documentApiType.data {
            document.data = stringData.asData
            document.beam_api_data = stringData.asData
        }

        document.title = documentApiType.title ?? document.title
        document.created_at = documentApiType.createdAt ?? document.created_at
        document.updated_at = documentApiType.updatedAt ?? document.updated_at
        document.deleted_at = documentApiType.deletedAt ?? document.deleted_at

        if let documentType = documentApiType.documentType {
            document.document_type = (documentType == .journal ? 0 : 1)
        }

        if let databaseIdString = documentApiType.database?.id,
           let databaseId = UUID(uuidString: databaseIdString) {
            document.database_id = databaseId
        }

        document.version += 1

        return true
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
//        document.version += 1
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

    private func isEqual(_ document: Document, to documentApiType: DocumentAPIType) -> Bool {
        guard let documentType = documentApiType.documentType else { return false }
        guard let updatedAt = documentApiType.updatedAt else { return false }
        guard let createdAt = documentApiType.createdAt else { return false }

        let documentTypeInt = (documentType == .journal ? 0 : 1)

        // Server side doesn't store milliseconds for updatedAt and createdAt. Local coredata does, rounding using Int()
        // to compare them

        return Int(document.updated_at.timeIntervalSince1970) == Int(updatedAt.timeIntervalSince1970) &&
            Int(document.created_at.timeIntervalSince1970) == Int(createdAt.timeIntervalSince1970) &&
            document.title == documentApiType.title &&
            document.data == documentApiType.data?.asData &&
            document.is_public == documentApiType.isPublic &&
            document.database_id.uuidString.lowercased() == documentApiType.database?.id &&
            document.beam_api_data == documentApiType.data?.asData &&
            document.document_type == documentTypeInt &&
            document.deleted_at == documentApiType.deletedAt &&
            document.id.uuidString.lowercased() == documentApiType.id
    }

    // MARK: Refresh
    private func refreshAllAndSave(_ delete: Bool = true,
                                   _ context: NSManagedObjectContext,
                                   _ documentAPITypes: [DocumentAPIType]) throws -> Bool {
        var remoteDocumentsIds: [UUID] = []
        var errors = false
        for documentAPIType in documentAPITypes {
            guard let uuid = documentAPIType.id?.uuid else {
                Logger.shared.logError("\(documentAPIType) has no id", category: .network)

                throw DocumentManagerError.idNotFound
            }
            remoteDocumentsIds.append(uuid)

            let document = Document.rawFetchOrCreateWithId(context, uuid)

            if self.isEqual(document, to: documentAPIType) {
                Logger.shared.logDebug("\(document.title): remote is equal to stored version",
                                       category: .document)
                continue
            }

            // Making sure we had no local updates, and simply overwritten the local version
            if !self.updateDocumentWithDocumentAPIType(document, documentAPIType) {
                errors = true
                Logger.shared.logError("\(documentAPIType) has local changes and couldn't be merged",
                                       category: .network)

                continue
            }

            notificationDocumentUpdate(DocumentStruct(document: document))
        }

        // This will be used in the next refresh, to only fetch delta
        if errors == false,
           let updatedAt = documentAPITypes.compactMap({ $0.updatedAt }).sorted().last {
            Persistence.Sync.Documents.updated_at = updatedAt
        }

        // Deleting local documents we haven't found remotely
        if delete {
            self.deleteNonExistingIds(context, remoteDocumentsIds)
        }

        return try Self.saveContext(context: context) && !errors
    }

    static var savedCount = 0
    // MARK: NSManagedObjectContext saves
    @discardableResult
    static func saveContext(context: NSManagedObjectContext) throws -> Bool {
        guard context.hasChanges else {
            return false
        }

        savedCount += 1

        do {
            try CoreDataManager.save(context)
            Logger.shared.logDebug("[\(savedCount)] CoreDataManager saved", category: .coredata)
            return true
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

            throw error
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
            let title = (conflict.sourceObject as? Document)?.title ?? ":( Document Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
        }
    }

    // MARK: Validations
    private func checkValidations(_ context: NSManagedObjectContext, _ document: Document) throws {
        try checkDuplicateTitles(context, document)
    }

    private func checkDuplicateTitles(_ context: NSManagedObjectContext, _ document: Document) throws {
        // If document is deleted, we don't need to check title uniqueness
        guard document.deleted_at == nil else { return }

        let predicate = NSPredicate(format: "title = %@ AND id != %@", document.title,
                                    document.id as CVarArg)
        let count = Document.countWithPredicate(context, predicate, document.database_id)
        if count > 0 {
            let errString = "Title is already used in \(count) other documents"
            let documents = (try? Document.fetchAll(context, predicate).map { DocumentStruct(document: $0) }) ?? []
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                           NSValidationObjectErrorKey: self,
                                           "documents": documents]
            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
        }
    }

    private func checkVersion(_ context: NSManagedObjectContext, _ document: Document, _ newVersion: Int64) throws {
        // If document is deleted, we don't need to check version uniqueness
        guard document.deleted_at == nil else { return }

        let existingDocument = try? Document.fetchWithId(context, document.id)

        if let existingVersion = existingDocument?.version, existingVersion >= newVersion {
            let errString = "\(document.title): coredata version: \(existingVersion), newVersion: \(newVersion)"
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString, NSValidationObjectErrorKey: self]
            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1002, userInfo: userInfo)
        }
    }

    // MARK: notifications
    private func notificationDocumentUpdate(_ documentStruct: DocumentStruct) {
        let userInfo: [AnyHashable: Any] = [
            "updatedDocuments": [documentStruct],
            "deletedDocuments": []
        ]

        Logger.shared.logDebug("Posting notification .documentUpdate for \(documentStruct.title) version \(documentStruct.version)", category: .document)

        NotificationCenter.default.post(name: .documentUpdate,
                                        object: self,
                                        userInfo: userInfo)
    }

    private func notificationDocumentDelete(_ documentStruct: DocumentStruct) {
        let userInfo: [AnyHashable: Any] = [
            "updatedDocuments": [],
            "deletedDocuments": [documentStruct]
        ]

        NotificationCenter.default.post(name: .documentUpdate,
                                        object: self,
                                        userInfo: userInfo)
    }

    // MARK: Shared
    private func predicateForSaveAll() -> NSPredicate? {
        var result: NSPredicate?

        // We only upload the documents we didn't yet send
        if let last_sent_at = Persistence.Sync.Documents.sent_all_at {
            result = NSPredicate(format: "(updated_at > %@ AND beam_api_sent_at < %@) OR updated_at > beam_api_sent_at",
                                 last_sent_at as NSDate,
                                 last_sent_at as NSDate)
        }
        return result
    }

    private func saveAndThrottle(_ documentStruct: DocumentStruct,
                                 _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        let document_id = documentStruct.id

        networkTasksSemaphore.wait()
        if let tuple = networkTasks[document_id] {
            tuple.0.cancel()
            tuple.1?(.failure(DocumentManagerError.operationCancelled))
        }
        networkTasksSemaphore.signal()

        let networkTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let context = self.coreDataManager.backgroundContext
            context.perform {
                // We want to fetch back the document, to update it's previousChecksum
                // context.refresh(document, mergeChanges: false)
                guard let updatedDocument = try? Document.fetchWithId(context, documentStruct.id) else {
                    Logger.shared.logError("Weird, document disappeared: \(documentStruct.id) \(documentStruct.title)", category: .coredata)
                    return
                }

                let updatedDocStruct = DocumentStruct(document: updatedDocument)
                self.saveDocumentStructOnAPI(updatedDocStruct) { result in
                    self.networkTasksSemaphore.wait()
                    self.networkTasks.removeValue(forKey: document_id)
                    self.networkTasksSemaphore.signal()
                    networkCompletion?(result)
                }
            }
        }

        networkTasksSemaphore.wait()
        networkTasks[document_id] = (networkTask, networkCompletion)
        networkTasksSemaphore.signal()
        backgroundQueue.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: networkTask)
    }
}

// MARK: - Foundation
extension DocumentManager {
    /// Use this to have updates when the underlaying CD object `Document` changes
    func onDocumentChange(_ documentStruct: DocumentStruct,
                          completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        Logger.shared.logDebug("onDocumentChange called for \(documentStruct.title)", category: .documentDebug)

        let cancellable = NotificationCenter.default
            .publisher(for: .documentUpdate)
            .sink { notification in
                // Skip notification coming from this manager
                if let documentManager = notification.object as? DocumentManager, documentManager == self {
                    return
                }

                if let updatedDocuments = notification.userInfo?["updatedDocuments"] as? [DocumentStruct] {
                    for document in updatedDocuments where document.id == documentStruct.id {
                        Logger.shared.logDebug("notification for \(document.title) version \(document.version)", category: .document)
                        completionHandler(document)
                    }
                }
            }
        return cancellable
    }

    func onDocumentDelete(_ documentStruct: DocumentStruct,
                          completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        Logger.shared.logDebug("onDocumentDelete called for \(documentStruct.title)", category: .documentDebug)

        let cancellable = NotificationCenter.default
            .publisher(for: .documentUpdate)
            .sink { notification in
                // Skip notification coming from this manager
                if let documentManager = notification.object as? DocumentManager, documentManager == self {
                    return
                }

                if let deletedDocuments = notification.userInfo?["deletedDocuments"] as? [DocumentStruct] {
                    for document in deletedDocuments where document.id == documentStruct.id {
                        Logger.shared.logDebug("notification for \(document.title) version \(document.version)", category: .document)
                        try? GRDBDatabase.shared.remove(noteTitled: document.title)
                        completionHandler(document)
                    }
                }
            }
        return cancellable
    }

    // MARK: -
    // MARK: Create
    func create(title: String) -> DocumentStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DocumentStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.create(context, title: title)

            do {
                try self.checkValidations(context, document)

                result = self.parseDocumentBody(document)
                try Self.saveContext(context: context)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .coredata)
            }

            semaphore.signal()
        }

        semaphore.wait()

        return result
    }

    func fetchOrCreateAsync(title: String, completion: ((DocumentStruct?) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.fetchOrCreateWithTitle(context, title)
            do {
                try self.checkValidations(context, document)
                try Self.saveContext(context: context)
                completion?(self.parseDocumentBody(document))
            } catch {
                completion?(nil)
            }
        }
    }

    func createAsync(title: String, completion: ((Swift.Result<DocumentStruct, Error>) -> Void)? = nil) {
        coreDataManager.backgroundContext.perform { [unowned self] in
            let context = self.coreDataManager.backgroundContext
            let document = Document.create(context, title: title)
            do {
                try self.checkValidations(context, document)
                try Self.saveContext(context: context)
                completion?(.success(self.parseDocumentBody(document)))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: -
    // MARK: Refresh

    /// When we sync all documents, we don't want to flag local documents not available remotely as deleted,
    /// as we might create document in the mean time (the UI does create a journal for today
    // TODO: A better way would be adding a "lock" mechanism to prevent all network calls when
    // we are in the process of a sync
    func syncAll(completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        saveAllOnAPI { result in
            if case .success(let success) = result, success == true {
                self.refreshAllFromAPI(delete: false, completion: completion)
                return
            }

            completion?(result)
        }
    }

    /// Fetch all remote documents from API
    func refreshAllFromAPI(delete: Bool = true, completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let documentRequest = DocumentRequest()

        let lastUpdatedAt = Persistence.Sync.Documents.updated_at
        if let lastUpdatedAt = lastUpdatedAt {
            Logger.shared.logDebug("Using updatedAt for documents API call: \(lastUpdatedAt)", category: .document)
        }

        do {
            try documentRequest.fetchAll(lastUpdatedAt) { result in
                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success(let documentAPITypes):
                    // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
                    // If not doing a delta sync, we don't as we want to update local document as `deleted`
                    if lastUpdatedAt != nil && documentAPITypes.count == 0 {
                        Logger.shared.logDebug("0 document fetched.", category: .document)
                        completion?(.success(true))
                        return
                    }

                    if let mostRecentUpdatedAt = documentAPITypes.compactMap({ $0.updatedAt }).sorted().last {
                        Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(documentAPITypes.count) documents fetched.",
                                               category: .document)
                    }
                    self.refreshAllSuccess(lastUpdatedAt == nil ? delete : false, documentAPITypes, completion)
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    private func refreshAllSuccess(_ delete: Bool = true,
                                   _ documentAPITypes: [DocumentAPIType],
                                   _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in

            do {
                let success = try self.refreshAllAndSave(delete, context, documentAPITypes)
                if !success {
                    completion?(.failure(DocumentManagerError.unresolvedConflict))
                } else {
                    completion?(.success(true))
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ objectStruct: DocumentStruct, _ forced: Bool = false, completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let documentRequest = DocumentRequest()

        if forced {
            refreshAlluccess(objectStruct, completion)
            return
        }

        do {
            try documentRequest.fetchDocumentUpdatedAt(objectStruct.uuidString) { result in
                switch result {
                case .failure(let error):
                    if case APIRequestError.notFound = error {
                        try? self.deleteLocalDocumentAndWait(objectStruct)
                    }

                    completion?(.failure(error))
                case .success(let documentType):
                    // If the document we fetched from the API has a lower updatedAt, we can skip it
                    guard let updatedAt = documentType.updatedAt, updatedAt > objectStruct.updatedAt else {
                        completion?(.success(false))
                        return
                    }
                    self.refreshAlluccess(objectStruct, completion)
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    private func refreshAlluccess(_ documentStruct: DocumentStruct,
                                  _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        let documentRequest = DocumentRequest()

        do {
            try documentRequest.fetchDocument(documentStruct.uuidString) { result in
                switch result {
                case .failure(let error):
                    if case APIRequestError.notFound = error {
                        try? self.deleteLocalDocumentAndWait(documentStruct)
                    }
                    completion?(.failure(error))
                case .success(let documentType):
                    self.refreshAlluccessSuccess(documentStruct, documentType, completion)
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    private func refreshAlluccessSuccess(_ documentStruct: DocumentStruct,
                                         _ documentType: DocumentAPIType,
                                         _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // Saving the remote version locally
        coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let document = try? Document.fetchWithId(context, documentStruct.id) else {
                completion?(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }

            // Making sure we had no local updates, and simply overwritten the local version
            if !self.updateDocumentWithDocumentAPIType(document, documentType) {
                completion?(.failure(DocumentManagerError.unresolvedConflict))
                return
            }

            self.notificationDocumentUpdate(DocumentStruct(document: document))

            do {
                completion?(.success(try Self.saveContext(context: context)))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: -
    // MARK: Save

    /// `saveDocument` will save locally in CoreData then call the completion handler
    /// If the user is authenticated, and network is enabled, it will also call the BeamAPI (async) to save the document remotely
    /// but will not trigger the completion handler. If the network callbacks updates the coredata object, it is expected the
    /// updates to be fetched through `onDocumentUpdate`
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func save(_ documentStruct: DocumentStruct,
              _ networkSave: Bool = true,
              _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil,
              completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(documentStruct.title) version \(documentStruct.version)", category: .document)
        Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

        var blockOperation: BlockOperation!

        blockOperation = BlockOperation { [weak self] in
            guard let self = self else { return }

            // In case the operationqueue was cancelled way before this started
            if blockOperation.isCancelled {
                completion?(.failure(DocumentManagerError.operationCancelled))
                return
            }
            let context = self.coreDataManager.backgroundContext

            context.performAndWait { [weak self] in
                guard let self = self else { return }

                if blockOperation.isCancelled {
                    completion?(.failure(DocumentManagerError.operationCancelled))
                    return
                }

                let document = Document.rawFetchOrCreateWithId(context, documentStruct.id)
                document.update(documentStruct)

                do {
                    try self.checkValidations(context, document)
                    try self.checkVersion(context, document, documentStruct.version)
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .document)
                    completion?(.failure(error))
                    return
                }

                document.version = documentStruct.version

                if let database = try? Database.rawFetchWithId(context, document.database_id) {
                    database.updated_at = BeamDate.now
                } else {
                    // We should always have a connected database
                    Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                }

                if blockOperation.isCancelled {
                    completion?(.failure(DocumentManagerError.operationCancelled))
                    return
                }

                do {
                    try Self.saveContext(context: context)
                } catch {
                    completion?(.failure(error))
                    return
                }

                // Ping others about the update
                self.notificationDocumentUpdate(documentStruct)

                if blockOperation.isCancelled {
                    completion?(.failure(DocumentManagerError.operationCancelled))
                    return
                }

                completion?(.success(true))

                // If not authenticated, we don't need to send to BeamAPI
                if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled, networkSave {
                    self.saveAndThrottle(documentStruct, networkCompletion)
                } else {
                    networkCompletion?(.failure(APIRequestError.notAuthenticated))
                }
            }
        }

        saveOperations[documentStruct.id]?.cancel()
        saveOperations[documentStruct.id] = blockOperation
        saveDocumentQueue.addOperation(blockOperation)
    }

    @discardableResult
    internal func saveDocumentStructOnAPI(_ documentStruct: DocumentStruct,
                                          _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return nil
        }

        Self.networkRequests[documentStruct.id]?.cancel()
        let documentRequest = DocumentRequest()
        Self.networkRequests[documentStruct.id] = documentRequest

        do {
            let documentApiType = documentStruct.asApiType()
            // Network call can take a while, if this document gets updated in the meantime it might not
            // be reuploaded in the next saveAll if this timestamp is after the new updated_at
            let beam_api_sent_at = BeamDate.now

            try documentRequest.save(documentApiType) { result in
                switch result {
                case .failure(let error):
                    if let error = error as NSError?, error.code == NSURLErrorCancelled {
                        completion?(.failure(error))
                        return
                    }
                    Logger.shared.logError(error.localizedDescription, category: .document)
                    self.saveDocumentStructOnAPIFailure(documentStruct, error, completion)
                case .success(let sentDocumentApiType):
                    // `previousChecksum` stores the checksum we sent to the API
                    var sentDocumentStruct = documentStruct.copy()
                    sentDocumentStruct.previousChecksum = sentDocumentApiType.document?.previousChecksum
                    self.saveDocumentStructOnAPISuccess(sentDocumentStruct,
                                                        beam_api_sent_at,
                                                        completion)
                }
            }
        } catch {
            completion?(.failure(error))
        }
        return nil
    }

    private func saveDocumentStructOnAPIFailure(_ documentStruct: DocumentStruct,
                                                _ error: Error,
                                                _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // We only manage conflicts, all other network errors are dispatched
        guard case APIRequestError.documentConflict = error else {
            completion?(.failure(error))
            return
        }

        Logger.shared.logDebug("Server rejected our update \(documentStruct.title): \(documentStruct.previousChecksum ?? "-")", category: .network)
        Logger.shared.logDebug("PreviousData: \(documentStruct.previousChecksum ?? "-")", category: .documentDebug)

        fetchAndMerge(documentStruct) { result in
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
                                                _ beam_api_sent_at: Date,
                                                _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let documentCoreData = try? Document.fetchWithId(context, documentStruct.id) else {
                completion?(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }

            // We save the remote stored version of the document, to know if we have local changes later
            // `beam_api_data` stores the last version we sent to the API
            // `beam_api_checksum` stores the checksum we sent to the API
            documentCoreData.beam_api_data = documentStruct.data
            documentCoreData.beam_api_checksum = documentStruct.previousChecksum
            documentCoreData.beam_api_sent_at = beam_api_sent_at

            do {
                let success = try Self.saveContext(context: context)
                completion?(.success(success))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: -
    // MARK: Delete
    func delete(id: UUID, completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in

            guard let document = try? Document.fetchWithId(context, id) else {
                completion?(.failure(DocumentManagerError.idNotFound))
                return
            }

            if let database = try? Database.rawFetchWithId(context, document.database_id) {
                database.updated_at = BeamDate.now
            } else {
                // We should always have a connected database
                Logger.shared.logError("No connected database", category: .document)
            }

            let documentStruct = DocumentStruct(document: document)
            document.delete(context)

            do {
                try Self.saveContext(context: context)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .document)
                completion?(.failure(error))
                return
            }

            // Ping others about the update
            self.notificationDocumentDelete(documentStruct)

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                completion?(.success(false))
                return
            }

            Self.networkRequests[id]?.cancel()
            let documentRequest = DocumentRequest()
            Self.networkRequests[id] = documentRequest

            do {
                try documentRequest.delete(id.uuidString.lowercased()) { result in
                    switch result {
                    case .failure(let error):
                        completion?(.failure(error))
                    case .success:
                        completion?(.success(true))
                    }
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }

    func deleteAll(includedRemote: Bool = true, completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        do {
            try Document.deleteBatchWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            completion?(.success(true))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let documentRequest = DocumentRequest()

        do {
            try documentRequest.deleteAll { result in
                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    // MARK: -
    // MARK: Merge and conflict management

    /// When sending a new local version of a document to the API and the API rejects it,
    /// we want to merge the new remote version, with our updated local version
    private func fetchAndMerge(_ document: DocumentStruct,
                               _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) {
        let documentRequest = DocumentRequest()

        do {
            try documentRequest.fetchDocument(document.uuidString) { [weak self] result in
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
        } catch {
            completion(.failure(error))
        }
    }

    // When having a conflict between versions
    // swiftlint:disable:next function_body_length
    private func manageDocumentConflictMerge(_ document: DocumentStruct,
                                             _ remoteDocument: DocumentAPIType,
                                             _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) {
        guard let remoteDataString = remoteDocument.data else {
            completion(.failure(DocumentManagerError.unresolvedConflict))
            return
        }

        do {
            let (newData, remoteData) = try self.mergeLocalAndRemote(document, remoteDocument)
            let localData = document.data

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
                guard let documentCoreData = try? Document.fetchWithId(context, document.id) else {
                    completion(.failure(DocumentManagerError.localDocumentNotFound))
                    return
                }
                documentCoreData.data = newData
                documentCoreData.beam_api_data = remoteData
                documentCoreData.beam_api_checksum = nil // enforce overwriting the API side

                do {
                    try Self.saveContext(context: context)
                    self.saveDocumentStructOnAPI(DocumentStruct(document: documentCoreData), completion)
                } catch {
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(DocumentManagerError.unresolvedConflict))
        }
    }

    // MARK: -
    // MARK: Bulk calls
    func saveAllOnAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            do {
                let sent_all_at = BeamDate.now
                let documents = (try? Document.rawFetchAll(context, self.predicateForSaveAll())) ?? []
                let documentsArray: [DocumentAPIType] = documents.map { document in document.asApiType(context) }
                let documentRequest = DocumentRequest()

                Logger.shared.logDebug("Uploading \(documents.count) documents", category: .document)
                if documents.count == 0 {
                    completion?(.success(true))
                    return
                }

                try documentRequest.saveAll(documentsArray) { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .network)
                        completion?(.failure(error))
                    case .success:
                        Logger.shared.logDebug("Documents uploaded", category: .network)
                        Persistence.Sync.Documents.sent_all_at = sent_all_at
                        context.performAndWait {
                            // TODO: do this with `NSBatchUpdateRequest` for performance
                            for document in documents { document.beam_api_sent_at = sent_all_at }
                            try? CoreDataManager.save(context)
                        }
                        completion?(.success(true))
                    }
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }
}

// MARK: Promises
extension DocumentManager {
    // MARK: -
    // MARK: Create
    func create(title: String) -> Promises.Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { context in
                try context.performAndWait {
                    let document = Document.create(context, title: title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                    return Promise(self.parseDocumentBody(document))
                }
            }
    }

    func fetchOrCreate(title: String) -> Promises.Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { context in
                try context.performAndWait {
                    let document = Document.fetchOrCreateWithTitle(context, title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                    return Promise(self.parseDocumentBody(document))
                }
            }
    }

    // MARK: -
    // MARK: Refresh

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ documentStruct: DocumentStruct) -> Promises.Promise<Bool> {
        let documentRequest = DocumentRequest()

        return documentRequest.fetchDocumentUpdatedAt(documentStruct.uuidString)
            .then(on: self.backgroundQueue) { documentType -> Promises.Promise<(DocumentAPIType, Bool)> in
                if let updatedAt = documentType.updatedAt, updatedAt > documentStruct.updatedAt {
                    return DocumentRequest().fetchDocument(documentStruct.uuidString).then { ($0, true) }
                }

                return Promise((documentType, false))
            }.then(on: self.backgroundQueue) { documentType, updated in
                if updated { try self.saveRefresh(documentStruct, documentType) }
            }.recover(on: self.backgroundQueue) { error throws -> Promises.Promise<(DocumentAPIType, Bool)> in
                if case APIRequestError.notFound = error {
                    try? self.deleteLocalDocumentAndWait(documentStruct)
                }
                throw error
            }.then(on: self.backgroundQueue) { _, updated in
                return updated
            }
    }

    func syncAll() -> Promises.Promise<Bool> {
        let promise: Promises.Promise<Bool> = saveAllOnAPI()

        return promise.then { result -> Promises.Promise<Bool> in
            guard result == true else { return Promise(result) }

            return self.refreshAllFromAPI()
        }
    }

    /// Fetch all remote documents from API
    func refreshAllFromAPI(_ delete: Bool = true) -> Promises.Promise<Bool> {
        let documentRequest = DocumentRequest()
        return documentRequest.fetchAll(Persistence.Sync.Documents.updated_at)
                .then(on: self.backgroundQueue) { documents -> Bool in
                    if let mostRecentUpdatedAt = documents.compactMap({ $0.updatedAt }).sorted().last {
                        Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(documents.count) documents fetched.",
                                               category: .document)
                    }

                    let context = self.coreDataManager.persistentContainer.newBackgroundContext()
                    return try context.performAndWait {
                        try self.refreshAllAndSave(delete, context, documents)
                    }
                }
    }

    // MARK: Save
    func save(_ documentStruct: DocumentStruct) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false
        let cancel = { cancelme = true }

        // Cancel previous promise
        saveDocumentPromiseCancels[documentStruct.id]?()
        saveDocumentPromiseCancels[documentStruct.id] = cancel

        let result = promise
            .then(on: self.backgroundQueue) { context -> Promises.Promise<Bool>  in
                Logger.shared.logDebug("Saving \(documentStruct.title)", category: .document)
                Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

                guard !cancelme else { throw DocumentManagerError.operationCancelled }

                return try context.performAndWait {
                    let document = Document.fetchOrCreateWithId(context, documentStruct.id)
                    document.update(documentStruct)

                    guard !cancelme else { throw DocumentManagerError.operationCancelled }
                    try self.checkValidations(context, document)

                    guard !cancelme else { throw DocumentManagerError.operationCancelled }

                    try Self.saveContext(context: context)

                    // Ping others about the update
                    self.notificationDocumentUpdate(DocumentStruct(document: document))

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return Promise(true)
                    }

                    self.saveAndThrottle(documentStruct)

                    return Promise(true)
                }
            }.always {
                self.saveDocumentPromiseCancels[documentStruct.id] = nil
            }

        return result
    }

    func saveOnApi(_ documentStruct: DocumentStruct) -> Promises.Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(true)
        }

        Self.networkRequests[documentStruct.id]?.cancel()
        let documentRequest = DocumentRequest()
        Self.networkRequests[documentStruct.id] = documentRequest

        // Network call can take a while, if this document gets updated in the meantime it might not
        // be reuploaded in the next saveAll if this timestamp is after the new updated_at
        let beam_api_sent_at = BeamDate.now
        let promise: Promises.Promise<DocumentAPIType> = documentRequest.save(documentStruct.asApiType())

        return promise.then(on: backgroundQueue) { documentApiType in
            guard !documentRequest.isCancelled else { throw DocumentManagerError.operationCancelled }

            let context = self.coreDataManager.persistentContainer.newBackgroundContext()
            try context.performAndWait {
                guard !documentRequest.isCancelled else { throw DocumentManagerError.operationCancelled }

                guard let documentCoreData = try? Document.fetchWithId(context, documentStruct.id) else {
                    throw DocumentManagerError.localDocumentNotFound
                }
                documentCoreData.beam_api_data = documentStruct.data
                documentCoreData.beam_api_checksum = documentApiType.previousChecksum
                documentCoreData.beam_api_sent_at = beam_api_sent_at

                try Self.saveContext(context: context)
            }

            return Promise(true)
        }.recover(on: backgroundQueue) { error throws -> Promises.Promise<Bool> in
            guard !documentRequest.isCancelled else { throw DocumentManagerError.operationCancelled }

            guard case APIRequestError.documentConflict = error else {
                throw error
            }

            return self.fetchAndMerge(documentStruct)
        }
    }

    private func fetchAndMerge(_ documentStruct: DocumentStruct) -> Promises.Promise<Bool> {
        let documentRequest = DocumentRequest()

        let promise: Promises.Promise<DocumentAPIType> = documentRequest.fetchDocument(documentStruct.uuidString)

        return promise.then(on: backgroundQueue) { documentAPIType -> DocumentStruct in
            let (newData, remoteData) = try self.mergeLocalAndRemote(documentStruct, documentAPIType)
            let context = self.coreDataManager.persistentContainer.newBackgroundContext()

            return try context.performAndWait {
                guard let documentCoreData = try? Document.fetchWithId(context, documentStruct.id) else {
                    throw DocumentManagerError.localDocumentNotFound
                }
                documentCoreData.data = newData
                documentCoreData.beam_api_data = remoteData
                documentCoreData.beam_api_checksum = nil // enforce overwriting the API side

                try Self.saveContext(context: context)

                return DocumentStruct(document: documentCoreData)
            }
        }.recover(on: backgroundQueue) { _ -> DocumentStruct in
            NotificationCenter.default.post(name: .apiDocumentConflict,
                                            object: documentStruct)
            // TODO: enforcing server overwrite for now by disabling checksum, but we should display a
            // conflict window and suggest to the user to keep a version or another, and not overwrite
            // existing data
            var clearedDocumentStruct = documentStruct.copy()
            clearedDocumentStruct.clearPreviousData()
            return clearedDocumentStruct
        }.then(on: backgroundQueue) { newDocumentStruct in
            self.saveOnApi(newDocumentStruct)
        }
    }

    // MARK: Delete
    func delete(id: UUID) -> Promises.Promise<Bool> {
        let documentRequest = DocumentRequest()

        return self.coreDataManager.background()
            .then(on: backgroundQueue) { context in
                context.performAndWait {
                    guard let document = try? Document.fetchWithId(context, id) else {
                        return
                    }

                    let documentStruct = DocumentStruct(document: document)

                    if let database = try? Database.rawFetchWithId(context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("No connected database", category: .document)
                    }

                    document.delete(context)

                    // Ping others about the update
                    self.notificationDocumentDelete(documentStruct)
                }

                guard AuthenticationManager.shared.isAuthenticated,
                      Configuration.networkEnabled else {
                    return Promise(true)
                }

                return documentRequest.delete(id.uuidString.lowercased())
                    .then(on: self.backgroundQueue) { _ in
                        return true
                    }
            }
    }

    func delete(ids: [UUID]) -> Promises.Promise<Bool> {
        return self.coreDataManager.background()
            .then(on: backgroundQueue) { context in

                context.performAndWait {
                    ids.forEach { id in
                        guard let document = try? Document.fetchWithId(context, id) else {
                            return
                        }
                        let documentStruct = DocumentStruct(document: document)

                        document.delete(context)
                        // Ping others about the update
                        self.notificationDocumentDelete(documentStruct)
                    }
                }

                // If not authenticated
                guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                    return Promise(true)
                }

                let promises: [Promises.Promise<DocumentAPIType?>] = ids.map { (id) in
                    Self.networkRequests[id]?.cancel()
                    let documentRequest = DocumentRequest()
                    Self.networkRequests[id] = documentRequest
                    return documentRequest.delete(id.uuidString.lowercased())
                }

                return Promises.all(promises).then { _ in return true }
            }
    }

    func deleteAll(includedRemote: Bool = true) -> Promises.Promise<Bool> {
        do {
            try Document.deleteBatchWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
            return Promise(error)
        }

        guard includedRemote,
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return Promise(true)
        }

        let documentRequest = DocumentRequest()

        return documentRequest.deleteAll()
    }

    // MARK: Bulk calls
    func saveAllOnAPI() -> Promises.Promise<Bool> {
        coreDataManager.background()
            .then(on: backgroundQueue) { _ -> Promises.Promise<Bool> in
                let context = self.coreDataManager.backgroundContext
                return context.performAndWait {
                    let documentRequest = DocumentRequest()
                    let sent_all_at = BeamDate.now
                    let documents = (try? Document.fetchAll(context, self.predicateForSaveAll())) ?? []
                    let documentsArray: [DocumentAPIType] = documents.map { document in document.asApiType() }

                    Logger.shared.logDebug("Uploading \(documents.count) documents", category: .document)
                    if documents.count == 0 {
                        return Promise(true)
                    }

                    let saveDocumentsPromise: Promises.Promise<DocumentRequest.UpdateDocuments> =
                        documentRequest.saveAll(documentsArray)

                    return saveDocumentsPromise.then { _ in
                        Persistence.Sync.Documents.sent_all_at = sent_all_at
                        context.performAndWait {
                            // TODO: do this with `NSBatchUpdateRequest` for performance
                            for document in documents { document.beam_api_sent_at = sent_all_at }
                            try? CoreDataManager.save(context)
                        }
                    }.then(on: self.backgroundQueue) { _ in true }
                }
            }
    }
}

// MARK: PromiseKit
extension DocumentManager {
    // MARK: -
    // MARK: Create

    func create(title: String) -> PromiseKit.Promise<DocumentStruct> {
        let promise: PromiseKit.Guarantee<NSManagedObjectContext> = coreDataManager.background()
        return promise
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<DocumentStruct> in
                try context.performAndWait {
                    let document = Document.create(context, title: title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                return .value(self.parseDocumentBody(document))
                }
            }
    }

    func fetchOrCreate(title: String) -> PromiseKit.Promise<DocumentStruct> {
        return coreDataManager.background()
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<DocumentStruct> in
                try context.performAndWait {
                    let document = Document.fetchOrCreateWithTitle(context, title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                    return .value(self.parseDocumentBody(document))
                }
            }
    }

    // MARK: -
    // MARK: Refresh

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ documentStruct: DocumentStruct) -> PromiseKit.Promise<Bool> {
        let documentRequest = DocumentRequest()

        let promise: PromiseKit.Promise<DocumentAPIType> = documentRequest.fetchDocumentUpdatedAt(documentStruct.uuidString)

        return promise
            .then(on: backgroundQueue) { documentType -> PromiseKit.Promise<(DocumentAPIType, Bool)> in
                if let updatedAt = documentType.updatedAt, updatedAt > documentStruct.updatedAt {
                    return DocumentRequest().fetchDocument(documentStruct.uuidString).map { ($0, true) }
                }
                return .value((documentType, false))
            }.get(on: backgroundQueue) { documentType, updated in
                if updated { try self.saveRefresh(documentStruct, documentType) }
            }.recover(on: backgroundQueue) { error -> PromiseKit.Promise<(DocumentAPIType, Bool)> in
                if case APIRequestError.notFound = error {
                    try? self.deleteLocalDocumentAndWait(documentStruct)
                }
                throw error
            }.map(on: backgroundQueue) { _, updated in
                return updated
            }
    }

    func syncDocuments() -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Promise<Bool> = saveAllOnAPI()

        return promise.then { result -> PromiseKit.Promise<Bool> in
            guard result == true else { return .value(result) }

            return self.refreshAllFromAPI()
        }
    }

    /// Fetch all remote documents from API
    func refreshAllFromAPI(_ delete: Bool = true) -> PromiseKit.Promise<Bool> {
        let documentRequest = DocumentRequest()

        let promise: PromiseKit.Promise<[DocumentAPIType]> =
            documentRequest.fetchAll(Persistence.Sync.Documents.updated_at)

        return promise
            .then(on: backgroundQueue) { documents -> PromiseKit.Promise<Bool> in
                if let mostRecentUpdatedAt = documents.compactMap({ $0.updatedAt }).sorted().last {
                    Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(documents.count) documents fetched.",
                                           category: .document)
                }
                let context = self.coreDataManager.persistentContainer.newBackgroundContext()
                let result = try context.performAndWait {
                    try self.refreshAllAndSave(delete, context, documents)
                }
                return .value(result)
            }
    }

    // MARK: Save
    func save(_ documentStruct: DocumentStruct) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Guarantee<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false

        // Cancel previous promise
        saveDocumentPromiseCancels[documentStruct.id]?()

        let result = promise
            .then(on: self.backgroundQueue) { context -> PromiseKit.Promise<Bool> in
                Logger.shared.logDebug("Saving \(documentStruct.title)", category: .document)
                Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

                guard !cancelme else { throw PMKError.cancelled }

                return try context.performAndWait {
                    let document = Document.fetchOrCreateWithId(context, documentStruct.id)
                    document.update(documentStruct)

                    guard !cancelme else { throw PMKError.cancelled }
                    try self.checkValidations(context, document)

                    guard !cancelme else { throw PMKError.cancelled }

                    try Self.saveContext(context: context)

                    // Ping others about the update
                    self.notificationDocumentUpdate(DocumentStruct(document: document))

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return .value(true)
                    }

                    /*
                     Something is broken around here, but I'll leave it as it is for now since promises are not used for
                     saving documents yet.

                     The completionHandler save() allows to get 2 handlers: one for saving, one for network call. The
                     promise version doesn't give any way to receive callbacks for network calls.
                     */

                    self.saveAndThrottle(documentStruct)

                    return .value(true)
                }
            }.ensure {
                self.saveDocumentPromiseCancels[documentStruct.id] = nil
            }

        let cancel = { cancelme = true }

        saveDocumentPromiseCancels[documentStruct.id] = cancel

        return result
    }

    func saveOnApi(_ documentStruct: DocumentStruct) -> PromiseKit.Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(true)
        }

        Self.networkRequests[documentStruct.id]?.cancel()
        let documentRequest = DocumentRequest()
        Self.networkRequests[documentStruct.id] = documentRequest

        // Network call can take a while, if this document gets updated in the meantime it might not
        // be reuploaded in the next saveAll if this timestamp is after the new updated_at
        let beam_api_sent_at = BeamDate.now
        let promise: PromiseKit.Promise<DocumentAPIType> = documentRequest.save(documentStruct.asApiType())

        return promise.then(on: backgroundQueue) { documentApiType -> PromiseKit.Promise<Bool> in
            guard !documentRequest.isCancelled else { throw DocumentManagerError.operationCancelled }

            let context = self.coreDataManager.persistentContainer.newBackgroundContext()
            try context.performAndWait {
                guard !documentRequest.isCancelled else { throw DocumentManagerError.operationCancelled }

                guard let documentCoreData = try? Document.fetchWithId(context, documentStruct.id) else {
                    throw DocumentManagerError.localDocumentNotFound
                }

                // We save the remote stored version of the document, to know if we have local changes later
                // `beam_api_data` stores the last version we sent to the API
                // `beam_api_checksum` stores the checksum we sent to the API
                documentCoreData.beam_api_data = documentStruct.data
                documentCoreData.beam_api_checksum = documentApiType.previousChecksum
                documentCoreData.beam_api_sent_at = beam_api_sent_at

                try Self.saveContext(context: context)
            }

            return .value(true)
        }.recover(on: backgroundQueue) { error -> PromiseKit.Promise<Bool> in
            guard !documentRequest.isCancelled else { throw DocumentManagerError.operationCancelled }

            guard case APIRequestError.documentConflict = error else {
                throw error
            }

            return self.fetchAndMerge(documentStruct)
        }
    }

    private func fetchAndMerge(_ documentStruct: DocumentStruct) -> PromiseKit.Promise<Bool> {
        let documentRequest = DocumentRequest()

        let promise: PromiseKit.Promise<DocumentAPIType> = documentRequest.fetchDocument(documentStruct.uuidString)

        return promise.then(on: backgroundQueue) { documentAPIType -> PromiseKit.Promise<DocumentStruct> in
            let (newData, remoteData) = try self.mergeLocalAndRemote(documentStruct, documentAPIType)

            let context = self.coreDataManager.persistentContainer.newBackgroundContext()
            return try context.performAndWait {
                guard let documentCoreData = try? Document.fetchWithId(context, documentStruct.id) else {
                    throw DocumentManagerError.localDocumentNotFound
                }
                documentCoreData.data = newData
                documentCoreData.beam_api_data = remoteData
                documentCoreData.beam_api_checksum = nil // enforce overwriting the API side

                try Self.saveContext(context: context)

                return .value(DocumentStruct(document: documentCoreData))
            }
        }.recover(on: backgroundQueue) { _ in
            NotificationCenter.default.post(name: .apiDocumentConflict,
                                            object: documentStruct)

            // TODO: enforcing server overwrite for now by disabling checksum, but we should display a
            // conflict window and suggest to the user to keep a version or another, and not overwrite
            // existing data
            var clearedDocumentStruct = documentStruct.copy()
            clearedDocumentStruct.clearPreviousData()
            return .value(clearedDocumentStruct)
        }.then(on: backgroundQueue) { documentStruct in
            self.saveOnApi(documentStruct)
        }
    }

    private func mergeLocalAndRemote(_ documentStruct: DocumentStruct, _ documentAPIType: DocumentAPIType) throws -> (Data, Data) {
        guard let beam_api_data = documentStruct.previousData,
              let remoteDataString = documentAPIType.data,
              let remoteData = documentAPIType.data?.asData else {
            throw DocumentManagerError.unresolvedConflict
        }
        let localData = documentStruct.data

        let data = BeamElement.threeWayMerge(ancestor: beam_api_data,
                                             input1: localData,
                                             input2: remoteData)

        guard let newData = data else {
            Logger.shared.logDebug("Couldn't merge the two versions for: \(documentStruct.title)", category: .documentMerge)
            Logger.shared.logDebug(prettyFirstDifferenceBetweenStrings(NSString(string: localData.asString ?? ""),
                                                                       NSString(string: remoteDataString)) as String,
                                   category: .documentMerge)
             throw DocumentManagerError.unresolvedConflict
        }

        return (newData, remoteData)
    }

    // MARK: Delete
    func delete(id: UUID) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Guarantee<NSManagedObjectContext> = coreDataManager.background()
        let documentRequest = DocumentRequest()

        return promise
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<Bool> in
                context.performAndWait {
                    guard let document = try? Document.fetchWithId(context, id) else {
                        return
                    }

                    let documentStruct = DocumentStruct(document: document)

                    if let database = try? Database.rawFetchWithId(context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("No connected database", category: .document)
                    }
                    document.delete(context)

                    // Ping others about the update
                    self.notificationDocumentDelete(documentStruct)
                }

                guard AuthenticationManager.shared.isAuthenticated,
                      Configuration.networkEnabled else {
                    return .value(true)
                }

                let result: PromiseKit.Promise<DocumentAPIType?> = documentRequest.delete(id.uuidString.lowercased())
                return result.map(on: self.backgroundQueue) { _ in true }
            }
    }

    func deleteAll(includedRemote: Bool = true) -> PromiseKit.Promise<Bool> {
        do {
            try Document.deleteBatchWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            return Promise(error: error)
        }

        guard includedRemote,
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return .value(true)
        }

        let documentRequest = DocumentRequest()
        let promise: PromiseKit.Promise<Bool> = documentRequest.deleteAll()
        return promise
    }

    // MARK: Bulk calls
    func saveAllOnAPI() -> PromiseKit.Promise<Bool> {
        self.coreDataManager.background()
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<Bool> in
                context.performAndWait {
                    let documentRequest = DocumentRequest()

                    let sent_all_at = BeamDate.now
                    let documents = (try? Document.rawFetchAll(context, self.predicateForSaveAll())) ?? []
                    let documentsArray: [DocumentAPIType] = documents.map { document in document.asApiType() }

                    Logger.shared.logDebug("Uploading \(documents.count) documents", category: .document)
                    if documents.count == 0 {
                        return .value(true)
                    }

                    let saveDocumentsPromise: PromiseKit.Promise<DocumentRequest.UpdateDocuments> =
                        documentRequest.saveAll(documentsArray)

                    return saveDocumentsPromise.get(on: self.backgroundQueue) { _ in
                        Persistence.Sync.Documents.sent_all_at = sent_all_at
                        context.performAndWait {
                            // TODO: do this with `NSBatchUpdateRequest` for performance
                            for document in documents { document.beam_api_sent_at = sent_all_at }
                            try? CoreDataManager.save(context)
                        }
                    }.map { _ in true }
                }
            }
    }
}
// swiftlint:enable file_length
