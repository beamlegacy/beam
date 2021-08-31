import Foundation
import CoreData
import Combine
import PMKFoundation
import BeamCore

// swiftlint:disable file_length

enum DocumentManagerError: Error, Equatable {
    case unresolvedConflict
    case localDocumentNotFound
    case idNotFound
    case operationCancelled
}

extension DocumentManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unresolvedConflict:
            return "unresolved Conflict"
        case .localDocumentNotFound:
            return "local Document Not Found"
        case .idNotFound:
            return "id Not Found"
        case .operationCancelled:
            return "operation cancelled"
        }
    }
}

// swiftlint:disable:next type_body_length
public class DocumentManager: NSObject {
    var coreDataManager: CoreDataManager
    let mainContext: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    let backgroundQueue = DispatchQueue(label: "DocumentManager backgroundQueue", qos: .background)

    let saveDocumentQueue = OperationQueue()
    var saveOperations: [UUID: BlockOperation] = [:]
    var saveDocumentPromiseCancels: [UUID: () -> Void] = [:]

    static var networkRequests: [UUID: APIRequest] = [:]
    static var networkTasks: [UUID: (DispatchWorkItem, ((Swift.Result<Bool, Error>) -> Void)?)] = [:]
    static var networkTasksSemaphore = DispatchSemaphore(value: 1)

    private var webSocketRequest = APIWebSocketRequest()

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

                return "\(document.title) {\(document.id)} version \(document.version)"
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
            Logger.shared.logDebug("All objects are invalidated: \(areInvalidatedAllObjects)", category: .coredataDebug)
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

    func allDocumentsTitles(includeDeletedNotes: Bool) -> [String] {
        let predicate = includeDeletedNotes ? nil : NSPredicate(format: "deleted_at == nil")
        if Thread.isMainThread {
            return Document.fetchAllNames(mainContext, predicate)
        } else {
            var result: [String] = []
            let context = coreDataManager.persistentContainer.newBackgroundContext()
            context.performAndWait {
                result = Document.fetchAllNames(context, predicate)
            }
            return result
        }
    }

    func allDocumentsIds(includeDeletedNotes: Bool) -> [UUID] {
        let predicate = includeDeletedNotes ? nil : NSPredicate(format: "deleted_at == nil")
        if Thread.isMainThread {
            let result = (try? Document.fetchAll(mainContext, predicate)) ?? []
            return result.map { $0.id }
        } else {
            var result: [Document] = []
            let context = coreDataManager.persistentContainer.newBackgroundContext()
            context.performAndWait {
                result = (try? Document.fetchAll(context, predicate)) ?? []
            }
            return result.map { $0.id }
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

    func loadDocumentByTitle(title: String,
                             context: NSManagedObjectContext? = nil,
                             completion: @escaping (Swift.Result<DocumentStruct?, Error>) -> Void) {
        let bgContext = context ?? CoreDataManager.shared.persistentContainer.newBackgroundContext()
        bgContext.perform {
            do {
                guard let document = try Document.fetchWithTitle(bgContext, title) else {
                    completion(.success(nil))
                    return
                }

                completion(.success(self.parseDocumentBody(document)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func loadDocumentById(id: UUID, context: NSManagedObjectContext? = nil) -> DocumentStruct? {
        guard let document = try? Document.fetchWithId(context ?? mainContext, id) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentsById(ids: [UUID], context: NSManagedObjectContext? = nil) -> [DocumentStruct] {
        do {
            return try Document.fetchAllWithIds(context ?? mainContext, ids).compactMap {
                parseDocumentBody($0)
            }
        } catch { return [] }
    }

    func loadDocumentWithJournalDate(_ date: String) -> DocumentStruct? {
        guard let document = Document.fetchWithJournalDate(mainContext, date) else { return nil }
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

    func documentsWithPredicate(_ predicate: NSPredicate) -> [DocumentStruct] {
        do {
            return try Document.fetchAll(mainContext, predicate)
                .compactMap { document -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func documentsWithLimitTitleMatch(title: String, limit: Int = 4, completion: @escaping (Swift.Result<[DocumentStruct], Error>) -> Void) {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        context.perform {
            do {
                let results = try Document.fetchAllWithLimitedTitleMatch(context, title, limit)
                    .compactMap { document -> DocumentStruct? in
                        self.parseDocumentBody(document)
                    }
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
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

    func parseDocumentBody(_ document: Document) -> DocumentStruct {
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
                       isPublic: document.is_public,
                       journalDate: document.document_type == DocumentType.journal.rawValue ? JournalDateConverter.toString(from: document.journal_day) : nil
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

    private func deleteLocalDocumentAndWait(_ id: UUID) throws {
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        try context.performAndWait {
            guard let document = try? Document.fetchWithId(context, id) else {
                return
            }

            document.deleted_at = BeamDate.now

            try Self.saveContext(context: context)
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
//        document.version += 1
        return true
    }

    func mergeDocumentWithNewData(_ document: Document, _ documentStruct: DocumentStruct) -> Bool {
        guard mergeWithLocalChanges(document, documentStruct.data) else {
            // Local version could not be merged with remote version
            Logger.shared.logWarning("Document has local change but could not merge", category: .documentMerge)
            NotificationCenter.default.post(name: .apiDocumentConflict,
                                            object: DocumentStruct(document: document))
            return false
        }

        // Local version was merged with remote version
        Logger.shared.logDebug("Document has local change! Merged both local and new received remote", category: .documentMerge)
        return true
    }

    private func isEqual(_ document: Document, to documentStruct: DocumentStruct) -> Bool {
        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        return document.updated_at.intValue == documentStruct.updatedAt.intValue &&
            document.created_at.intValue == documentStruct.createdAt.intValue &&
            document.title == documentStruct.title &&
            document.data == documentStruct.data &&
            document.is_public == documentStruct.isPublic &&
            document.database_id == documentStruct.databaseId &&
            document.document_type == documentStruct.documentType.rawValue &&
            document.deleted_at?.intValue == documentStruct.deletedAt?.intValue &&
            document.id == documentStruct.id
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
            let localTimer = BeamDate.now
            try CoreDataManager.save(context)
            Logger.shared.logDebug("[\(savedCount)] CoreDataManager saved", category: .coredata, localTimer: localTimer)
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
    func checkValidations(_ context: NSManagedObjectContext, _ document: Document) throws {
        Logger.shared.logDebug("checkValidations for \(document.titleAndId)", category: .documentDebug)
        try checkJournalDay(document)
        try checkDuplicateJournalDates(context, document)
        try checkDuplicateTitles(context, document)
    }

    private func checkJournalDay(_ document: Document) throws {
        guard document.documentType == .journal else { return }
        guard String(document.journal_day).count != 8 else {return}

        let errString = "journal_day is \(document.journal_day) for \(document.titleAndId)"

        Logger.shared.logError(errString, category: .document)

        let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                       NSValidationObjectErrorKey: self]
        throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1003, userInfo: userInfo)
    }

    private func checkDuplicateJournalDates(_ context: NSManagedObjectContext, _ document: Document) throws {
        // If document is deleted, we don't need to check title uniqueness
        guard document.deleted_at == nil else { return }
        guard document.documentType == .journal else { return }
        guard String(document.journal_day).count == 8 else {return}

        let predicate = NSPredicate(format: "journal_day == %d AND id != %@ AND deleted_at == nil AND database_id = %@",
                                    document.journal_day,
                                    document.id as CVarArg,
                                    document.database_id as CVarArg)
        let documents = (try? Document.fetchAll(context, predicate).map { DocumentStruct(document: $0) }) ?? []

        if !documents.isEmpty {
            let errString = "Journal Date \(document.journal_day) for \(document.titleAndId) already used in \(documents.count) other documents"

            Logger.shared.logWarning(errString, category: .document)

            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                           NSValidationObjectErrorKey: self,
                                           "documents": documents]

            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1004, userInfo: userInfo)
        }
    }

    func checkDuplicateTitles(_ context: NSManagedObjectContext, _ document: Document) throws {
        // If document is deleted, we don't need to check title uniqueness
        guard document.deleted_at == nil else { return }

        let predicate = NSPredicate(format: "title = %@ AND id != %@ AND deleted_at == nil AND database_id = %@",
                                    document.title,
                                    document.id as CVarArg,
                                    document.database_id as CVarArg)
        let documents = (try? Document.fetchAll(context, predicate).map { DocumentStruct(document: $0) }) ?? []

        if !documents.isEmpty {
            let errString = "Title \(document.titleAndId) is already used in \(documents.count) other documents"

            Logger.shared.logWarning(errString, category: .document)

            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                           NSValidationObjectErrorKey: self,
                                           "documents": documents]

            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
        }
    }

    func checkVersion(_ context: NSManagedObjectContext, _ document: Document, _ newVersion: Int64) throws {
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
    func notificationDocumentUpdate(_ documentStruct: DocumentStruct) {
        let userInfo: [AnyHashable: Any] = [
            "updatedDocuments": [documentStruct],
            "deletedDocuments": []
        ]

        Logger.shared.logDebug("Posting notification .documentUpdate for \(documentStruct.titleAndId)",
                               category: .documentNotification)

        NotificationCenter.default.post(name: .documentUpdate,
                                        object: self,
                                        userInfo: userInfo)
    }

    func notificationDocumentDelete(_ documentStruct: DocumentStruct) {
        let userInfo: [AnyHashable: Any] = [
            "updatedDocuments": [],
            "deletedDocuments": [documentStruct]
        ]

        Logger.shared.logDebug("Posting notification .documentUpdate for deleted \(documentStruct.titleAndId)",
                               category: .documentNotification)

        NotificationCenter.default.post(name: .documentUpdate,
                                        object: self,
                                        userInfo: userInfo)
    }

    // MARK: Shared
    func predicateForSaveAll() -> NSPredicate? {
        var result: NSPredicate?

        // We only upload the documents we didn't yet send
        if let last_sent_at = Persistence.Sync.Documents.sent_all_at {
            result = NSPredicate(format: "(updated_at > %@ AND beam_api_sent_at < %@) OR updated_at > beam_api_sent_at",
                                 last_sent_at as NSDate,
                                 last_sent_at as NSDate)
        }
        return result
    }

    func saveAndThrottle(_ documentStruct: DocumentStruct,
                         _ delay: Double = 1.0,
                         _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        let document_id = documentStruct.id

        // This is not using `cancelPreviousThrottledAPICall` as we want to:
        // * use the semaphore on the whole `saveAndThrottle` method, to avoid RACE
        // * call the network completionHandler now so any previous calls are aware a previous network save has been cancelled
        Self.networkTasksSemaphore.wait()
        defer { Self.networkTasksSemaphore.signal() }

        if let tuple = Self.networkTasks[document_id] {
            tuple.0.cancel()
            tuple.1?(.failure(DocumentManagerError.operationCancelled))
        }

        var networkTask: DispatchWorkItem!

        networkTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId) executing",
                                   category: .documentNetwork)
            let localTimer = BeamDate.now

            let context = self.coreDataManager.backgroundContext
            context.perform {
                // We want to fetch back the document, to update it's previousChecksum
                // context.refresh(document, mergeChanges: false)
                guard let updatedDocument = try? Document.fetchWithId(context, documentStruct.id) else {
                    Logger.shared.logWarning("Weird, document disappeared (deleted?), isCancelled: \(networkTask.isCancelled): \(documentStruct.titleAndId)",
                                             category: .coredata)
                    networkCompletion?(.failure(DocumentManagerError.localDocumentNotFound))
                    return
                }

                self.saveDocumentStructOnAPI(DocumentStruct(document: updatedDocument)) { result in
                    Self.networkTasksSemaphore.wait()
                    Self.networkTasks.removeValue(forKey: document_id)
                    Self.networkTasksSemaphore.signal()
                    networkCompletion?(result)
                    Logger.shared.logDebug("Network task for \(documentStruct.titleAndId) executed",
                                           category: .documentNetwork,
                                           localTimer: localTimer)
                }
            }
        }

        Self.networkTasks[document_id] = (networkTask, networkCompletion)
        // `asyncAfter` will not execute before `deadline` but might be executed later. It is not accurate.
        // TODO: use `Timer.scheduledTimer` or `perform:with:afterDelay`
        backgroundQueue.asyncAfter(deadline: .now() + delay, execute: networkTask)
        Logger.shared.logDebug("Adding network task for \(documentStruct.titleAndId)", category: .documentNetwork)
    }
}

// MARK: - BeamObjectManagerDelegateProtocol
extension DocumentManager: BeamObjectManagerDelegate {
    func willSaveAllOnBeamObjectApi() {
        Self.cancelAllPreviousThrottledAPICall()
    }

    static var conflictPolicy: BeamObjectConflictResolution = .fetchRemoteAndError

    func persistChecksum(_ objects: [DocumentStruct]) throws {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        try context.performAndWait {
            var changed = false

            for updateObject in objects {
                guard let documentCoreData = try? Document.fetchWithId(context, updateObject.id) else {
                    throw DocumentManagerError.localDocumentNotFound
                }

                /*
                 `persistChecksum` might be called more than once for the same object, if you save one object and
                 it conflicts, once merged it will call saveOnBeamAPI() again and there will be no way to know this
                 2nd save doesn't need to persist checksum, unless passing a method attribute `dontSaveChecksum`
                 which is annoying as a pattern.

                 Instead I just check if it's the same, with same previous data and we skip the save to avoid a
                 CD save.
                 */
                guard documentCoreData.beam_object_previous_checksum != updateObject.previousChecksum ||
                        documentCoreData.beam_api_data != updateObject.data else {
                    Logger.shared.logDebug("PersistChecksum \(updateObject.titleAndId) already set \(updateObject.previousChecksum ?? "-")",
                                           category: .documentNetwork)
                    continue
                }

                Logger.shared.logDebug("PersistChecksum \(updateObject.titleAndId) with previous checksum \(updateObject.previousChecksum ?? "-")",
                                       category: .documentNetwork)
                documentCoreData.beam_object_previous_checksum = updateObject.previousChecksum
                documentCoreData.beam_api_data = updateObject.data

                changed = true
            }

            if changed { try Self.saveContext(context: context) }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func receivedObjects(_ documents: [DocumentStruct]) throws {
        Logger.shared.logDebug("Received \(documents.count) documents: \(documents.map { $0.beamObjectId.uuidString.lowercased() }.joined(separator: ", "))",
                               category: .documentNetwork)

        var changedDocuments: Set<DocumentStruct> = Set()
        let localTimer = BeamDate.now

        let context = coreDataManager.backgroundContext
        try context.performAndWait {
            var changed = false

            for var document in documents {
                var localDocument = Document.rawFetchOrCreateWithId(context, document.id)

                if self.isEqual(localDocument, to: document) {
                    Logger.shared.logDebug("\(document.titleAndId): remote is equal to struct version, skip",
                                           category: .documentNetwork)
                    continue
                }

                if document.checksum == localDocument.beam_object_previous_checksum &&
                    document.data == localDocument.beam_api_data {
                    Logger.shared.logDebug("Received object \(document.titleAndId), but has same checksum \(document.checksum ?? "-") and previous data, skip",
                                           category: .documentNetwork)
                    continue
                }

                var good = false
                var (originalTitle, index) = document.title.originalTitleWithIndex()

                while !good && index < 10 {
                    do {
                        if localDocument.objectID.isTemporaryID || !self.mergeDocumentWithNewData(localDocument, document) {
                            localDocument.data = document.data
                        }

                        localDocument.update(document)
                        Logger.shared.logDebug("Received object \(document.titleAndId), set previous checksum \(document.checksum ?? "-")",
                                               category: .documentNetwork)

                        localDocument.beam_object_previous_checksum = document.checksum
                        localDocument.version += 1

                        try checkValidations(context, localDocument)

                        let savedDoc = DocumentStruct(document: localDocument)
                        self.notificationDocumentUpdate(savedDoc)
                        indexDocument(savedDoc)

                        good = true
                        changed = true
                    } catch {
                        guard (error as NSError).domain == "DOCUMENT_ERROR_DOMAIN" else {
                            Logger.shared.logError(error.localizedDescription, category: .documentNetwork)
                            throw error
                        }

                        switch (error as NSError).code {
                        case 1001, 1004:
                            let conflictedDocuments = (error as NSError).userInfo["documents"] as? [DocumentStruct]

                            // When receiving empty documents from the API and conflict with existing documents,
                            // we delete them if they're empty. That happens with today's journal for example

                            // Remote document is empty, we delete it
                            if document.isEmpty {
                                document.deletedAt = BeamDate.now
                                localDocument.deleted_at = document.deletedAt
                                Logger.shared.logWarning("Title or JournalDate is in conflict but remote document is empty, deleting",
                                                         category: .documentNetwork)

                                changedDocuments.insert(document)
                            // Local document is empty, we either delete it if never saved, or soft delete it
                            } else if let conflictedDocuments = conflictedDocuments,
                                      !conflictedDocuments.compactMap({ $0.isEmpty }).contains(false) {
                                // local conflicted documents are empty, deleting them
                                for localConflictedDocument in conflictedDocuments {
                                    guard let localConflictedDocumentCD = try? Document.fetchWithId(context, localConflictedDocument.id) else { continue }

                                    // We already saved this document, we must propagate its deletion
                                    if localConflictedDocumentCD.beam_api_sent_at != nil {
                                        localConflictedDocumentCD.deleted_at = BeamDate.now
                                        changedDocuments.insert(DocumentStruct(document: localConflictedDocumentCD))
                                        Logger.shared.logWarning("Title or JournalDate is in conflict, but local documents are empty, soft deleting",
                                                                 category: .documentNetwork)
                                    } else {
                                        context.delete(localConflictedDocumentCD)
                                        Logger.shared.logWarning("Title or JournalDate is in conflict, but local documents are empty, deleting",
                                                                 category: .documentNetwork)
                                    }
                                }

                            } else {
                                document.title = "\(originalTitle) (\(index))"
                                Logger.shared.logWarning("Title or JournalDate is in conflict, neither local or remote are empty.",
                                                         category: .documentNetwork)
                                changedDocuments.insert(document)
                            }

                            index += 1
                        case 1002:
                            Logger.shared.logWarning("Version \(localDocument.version) is higher than \(document.version)",
                                                     category: .documentNetwork)
                            localDocument = Document.rawFetchOrCreateWithId(context, document.id)
                            Logger.shared.logWarning("After reload: \(localDocument.version)",
                                                     category: .documentNetwork)

                        default: break
                        }
                    }
                }
            }

            if changed {
                try Self.saveContext(context: context)
            }
        }

        if !changedDocuments.isEmpty {
            try saveOnBeamObjectsAPI(Array(changedDocuments)) { _ in }
        }

        Logger.shared.logDebug("Received \(documents.count) documents: done. \(changedDocuments.count) remodified.",
                               category: .documentNetwork,
                               localTimer: localTimer)
    }

    func indexDocument(_ docStruct: DocumentStruct) {
        BeamNote.indexingQueue.async {
            let decoder = JSONDecoder()
            do {
                let note = try decoder.decode(BeamNote.self, from: docStruct.data)
                try GRDBDatabase.shared.append(note: note)
            } catch {
                Logger.shared.logError("Error while trying to index synced note '\(docStruct.title)' [\(docStruct.id)]: \(error)", category: .document)
            }
        }
    }

    func allObjects() throws -> [DocumentStruct] {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        // Note: when this becomes a memory hog because we manipulate all local documents, we'll want to loop through
        // them by 100s and make multiple network calls instead.
        return try context.performAndWait {
            try Document.rawFetchAll(context).map {
                var result = DocumentStruct(document: $0)
                result.previousChecksum = result.beamObjectPreviousChecksum
                return result
            }
        }
    }

    private func saveDatabaseAndDocumentOnBeamObjectAPI(_ documentStruct: DocumentStruct,
                                                        _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws {

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        var dbStruct: DatabaseStruct?
        try context.performAndWait {
            guard let dbDatabase = try Database.rawFetchWithId(context, documentStruct.databaseId) else { return }
            dbStruct = DatabaseStruct(database: dbDatabase)
        }

        guard let databaseStruct = dbStruct else {
            throw DatabaseManagerError.localDatabaseNotFound
        }

        let databaseManager = DatabaseManager()

        // TODO: add a way to cancel the database API calls
        _ = try databaseManager.saveOnBeamObjectAPI(databaseStruct) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                do {
                    try self.saveOnBeamObjectAPI(documentStruct) { result in
                        switch result {
                        case .failure(let error): completion(.failure(error))
                        case .success: completion(.success(true))
                        }
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func saveObjectsAfterConflict(_ objects: [DocumentStruct]) throws {
        let context = coreDataManager.backgroundContext
        try context.performAndWait {
            for document in objects {
                let localDocument = Document.rawFetchOrCreateWithId(context, document.id)

                if self.isEqual(localDocument, to: document) {
                    Logger.shared.logDebug("\(document.title) {\(document.id)}: remote is equal to struct version, skip",
                                           category: .documentNetwork)
                    continue
                }

                localDocument.update(document)
                localDocument.data = document.data

                Logger.shared.logDebug("Saved after conflict \(document.title) {\(document.id)}, set previous checksum \(document.checksum ?? "-")",
                                       category: .documentNetwork)

                localDocument.beam_object_previous_checksum = document.checksum
                localDocument.version += 1

                try checkValidations(context, localDocument)
                self.notificationDocumentUpdate(DocumentStruct(document: localDocument))
            }
            try Self.saveContext(context: context)
        }
    }

    func manageConflict(_ documentStruct: DocumentStruct,
                        _ remoteDocumentStruct: DocumentStruct) throws -> DocumentStruct {
        Logger.shared.logWarning("Could not save \(documentStruct.titleAndId) because of conflict", category: .documentNetwork)

        let context = self.coreDataManager.persistentContainer.newBackgroundContext()

        var result = documentStruct.copy()

        // Merging might fail, in such case we send the remote version of the document
        context.performAndWait {
            let document = Document.rawFetchOrCreateWithId(context, documentStruct.id)
            if let beam_api_data = document.beam_api_data,
               let data = BeamElement.threeWayMerge(ancestor: beam_api_data,
                                                    input1: documentStruct.data,
                                                    input2: remoteDocumentStruct.data) {
                Logger.shared.logDebug("Could merge both automatically", category: .documentNetwork)
                result.data = data
            } else {
                // We can't save the most recent one as it's always be the local version, as we update `updatedAt` way
                // too often.
                Logger.shared.logWarning("Could not merge both automatically, resending remote document",
                                         category: .documentNetwork)
            }
            result.version = document.version
        }

        if let beamNote = try? BeamNote.instanciateNote(result, keepInMemory: false, decodeChildren: true) {
            Logger.shared.logDebug(beamNote.textDescription(), category: .documentNetwork)
        }

        // Not incrementing `version` on purpose, this is only used to send the merged object back to the API
        result.updatedAt = BeamDate.now

        return result
    }
}

extension DocumentManager {
    public override var description: String { "Beam.DocumentManager" }
}
// swiftlint:enable file_length
