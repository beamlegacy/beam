import Foundation
import CoreData
import Combine
import PMKFoundation
import BeamCore

enum DocumentManagerError: Error {
    case unresolvedConflict
    case localDocumentNotFound
    case idNotFound
    case operationCancelled
    case networkNotCalled
    case multipleErrors([Error])
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
        case .networkNotCalled:
            return "network not called"
        case .multipleErrors(let errors):
            return "multiple errors: \(errors)"
        }
    }
}

enum DocumentFilter {
    case allDatabases
    case databaseId(UUID)
    case notDatabaseId(UUID)
    case notDatabaseIds([UUID])
    case id(UUID)
    case notId(UUID)
    case ids([UUID])
    case notIds([UUID])
    case title(String)
    case titleMatch(String)
    case journalDate(Int64)
    case beforeJournalDate(Int64)
    case nonFutureJournalDate(Int64)
    case type(DocumentType)
    /// filter out deleted notes (the default if nothing is explicitely requested)
    case nonDeleted
    /// filter out non delete notes
    case deleted
    /// don't filter out anything
    case includeDeleted
    case updatedSince(Date)

    case limit(Int)
    case offset(Int)

}

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public class DocumentManager: NSObject {
    var coreDataManager: CoreDataManager
    var context: NSManagedObjectContext
    static let backgroundQueue = DispatchQueue(label: "co.beamapp.documentManager.backgroundQueue", qos: .default)
    var backgroundQueue: DispatchQueue { Self.backgroundQueue }

    static let saveDocumentQueue = DispatchQueue(label: "co.beamapp.documentManager.saveQueue", qos: .userInitiated)
    var saveDocumentQueue: DispatchQueue { Self.saveDocumentQueue }

    var saveDocumentPromiseCancels: [UUID: () -> Void] = [:]

    //swiftlint:disable:next large_tuple
    static var networkTasks: [UUID: (DispatchWorkItem, Bool, ((Swift.Result<Bool, Error>) -> Void)?)] = [:]
    static var networkTasksSemaphore = DispatchSemaphore(value: 1)
    var thread: Thread
    @discardableResult func checkThread() -> Bool {
        let res = self.thread == Thread.current

        if !res {
            Logger.shared.logError("Using DocumentManager instance outside its origin thread", category: .document)
        }
        #if DEBUG
        assert(res)
        #endif

        return res
    }

    init(coreDataManager: CoreDataManager? = nil) {
        self.thread = Thread.current
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        context = Thread.isMainThread ? self.coreDataManager.mainContext : self.coreDataManager.persistentContainer.newBackgroundContext()

        super.init()
    }

    // MARK: Coredata Updates
    @objc func managedObjectContextObjectsDidChange(_ notification: Notification) {
        printObjects(notification)
    }

    private func printObjectsFromNotification(_ notification: Notification, _ keyPath: String) {
        checkThread()
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
        checkThread()
        printObjectsFromNotification(notification, NSInsertedObjectsKey)
        printObjectsFromNotification(notification, NSUpdatedObjectsKey)
        printObjectsFromNotification(notification, NSDeletedObjectsKey)
        printObjectsFromNotification(notification, NSRefreshedObjectsKey)
        printObjectsFromNotification(notification, NSInvalidatedObjectsKey)

        if let areInvalidatedAllObjects = notification.userInfo?[NSInvalidatedAllObjectsKey] as? Bool {
            Logger.shared.logDebug("All objects are invalidated: \(areInvalidatedAllObjects)", category: .coredataDebug)
        }
    }

    // MARK: CoreData Load
    func loadById(id: UUID, includeDeleted: Bool) -> DocumentStruct? {
        checkThread()
        guard let document = try? self.fetchWithId(id, includeDeleted: includeDeleted) else { return nil }

        return parseDocumentBody(document)
    }

    func fetchOrCreate(_ title: String, id: UUID = UUID(), deletedAt: Date?) -> DocumentStruct? {
        checkThread()
        do {
            let document: Document = try fetchOrCreate(title, id: id, deletedAt: deletedAt)
            return parseDocumentBody(document)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
            return nil
        }
    }

    func allDocumentsTitles(includeDeletedNotes: Bool) -> [String] {
        checkThread()
        return fetchAllNames(filters: includeDeletedNotes ? [.includeDeleted] : [])
    }

    func allDocumentsIds(includeDeletedNotes: Bool) -> [UUID] {
        checkThread()
        let result = (try? fetchAll(filters: includeDeletedNotes ? [.includeDeleted] : [])) ?? []
        return result.map { $0.id }
    }

    func loadDocByTitleInBg(title: String) -> DocumentStruct? {
        checkThread()
        guard let document = try? fetchWithTitle(title) else { return nil }
        return parseDocumentBody(document)
    }

    func loadDocumentByTitle(title: String) -> DocumentStruct? {
        checkThread()
        guard let document = try? fetchWithTitle(title) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentByTitle(title: String,
                             completion: @escaping (Swift.Result<DocumentStruct?, Error>) -> Void) {
        backgroundQueue.async {
            let documentManager = DocumentManager()
            do {
                guard let document = try documentManager.fetchWithTitle(title) else {
                    completion(.success(nil))
                    return
                }

                completion(.success(documentManager.parseDocumentBody(document)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func loadDocumentById(id: UUID, includeDeleted: Bool) -> DocumentStruct? {
        checkThread()
        guard let document = try? fetchWithId(id, includeDeleted: includeDeleted) else { return nil }
        return parseDocumentBody(document)
    }

    func loadDocumentsById(ids: [UUID]) -> [DocumentStruct] {
        checkThread()
        do {
            return try fetchAllWithIds(ids).compactMap {
                parseDocumentBody($0)
            }
        } catch { return [] }
    }

    func loadDocumentWithJournalDate(_ date: String) -> DocumentStruct? {
        checkThread()
        guard let document = fetchWithJournalDate(date) else { return nil }
        return parseDocumentBody(document)
    }

    func loadDocumentsWithType(type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [DocumentStruct] {
        checkThread()
        do {
            let today = BeamNoteType.titleForDate(BeamDate.now)
            let todayInt = JournalDateConverter.toInt(from: today)

            return try fetchAll(filters: [.type(type), .nonFutureJournalDate(todayInt), .limit(limit), .offset(fetchOffset)], sortingKey: .journal(false)).compactMap { (document) -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func documentsWithTitleMatch(title: String) -> [DocumentStruct] {
        checkThread()
        do {
            return try fetchAllWithTitleMatch(title: title, limit: 0)
                .compactMap { document -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func documentsWithTitleMatch(title: String, completion: @escaping (Swift.Result<[DocumentStruct], Error>) -> Void) {
        backgroundQueue.async {
            do {
                let documentManager = DocumentManager()
                let results = try documentManager.fetchAllWithTitleMatch(title: title, limit: 0)
                    .compactMap { document -> DocumentStruct? in
                        documentManager.parseDocumentBody(document)
                    }
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func documentsWithLimitTitleMatch(title: String, limit: Int = 4, completion: @escaping (Swift.Result<[DocumentStruct], Error>) -> Void) {
        backgroundQueue.async {
            let documentManager = DocumentManager()
            do {
                let results = try documentManager.fetchAllWithTitleMatch(title: title, limit: limit)
                    .compactMap { document -> DocumentStruct? in
                        documentManager.parseDocumentBody(document)
                    }
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func documentsWithLimitTitleMatch(title: String, limit: Int = 4) -> [DocumentStruct] {
        checkThread()
        do {
            return try fetchAllWithTitleMatch(title: title, limit: limit)
                .compactMap { document -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func loadAllWithLimit(_ limit: Int = 4, sortingKey: SortingKey? = nil, type: DocumentType? = nil) -> [DocumentStruct] {
        checkThread()
        var filters: [DocumentFilter] = [.limit(limit)]
        if let type = type {
            filters.append(.type(type))
        }
        do {
            return try fetchAll(filters: filters, sortingKey: sortingKey).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
                }
        } catch { return [] }
    }

    func loadAll() -> [DocumentStruct] {
        checkThread()
        do {
            return try fetchAll().compactMap { document in
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
                       version: document.version,
                       isPublic: document.is_public,
                       journalDate: document.document_type == DocumentType.journal.rawValue ? JournalDateConverter.toString(from: document.journal_day) : nil
        )
    }

    /// Update local coredata instance with data we fetched remotely, we detected the need for a merge between both versions
    private func mergeWithLocalChanges(_ document: Document, _ input2: Data) -> Bool {
        checkThread()
        let documentStruct = DocumentStruct(document: document)
        guard let beam_api_data = documentStruct.previousSavedObject?.data,
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
        return true
    }

    func mergeDocumentWithNewData(_ document: Document, _ remoteDocumentStruct: DocumentStruct) -> Bool {
        checkThread()

        guard document.data != nil else {
            Logger.shared.logError("You should not call this method when data is nil", category: .documentMerge)
            return false
        }

        // If the local data is equal to what was previously saved (hasLocalChanges), we have no local motification.
        // We can just use the remote document and store it as our new local document.
        guard DocumentStruct(document: document).hasLocalChanges else {
            Logger.shared.logDebug("Document has no local change", category: .documentMerge)
            return false
        }

        Logger.shared.logDebug("Document has local change", category: .documentMerge)

        guard mergeWithLocalChanges(document, remoteDocumentStruct.data) else {
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

    func isEqual(_ document: Document, to documentStruct: DocumentStruct) -> Bool {
        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        document.updated_at.intValue == documentStruct.updatedAt.intValue &&
            document.created_at.intValue == documentStruct.createdAt.intValue &&
            document.title == documentStruct.title &&
            document.data == documentStruct.data &&
            document.is_public == documentStruct.isPublic &&
            document.database_id == documentStruct.databaseId &&
            document.document_type == documentStruct.documentType.rawValue &&
            document.deleted_at?.intValue == documentStruct.deletedAt?.intValue &&
            document.id == documentStruct.id
    }

    private func addLogLine(_ objects: Set<NSManagedObject>, name: String) {
        guard !objects.isEmpty else { return }
        var dict: [String: Int] = [:]

        for object in objects {
            guard let name = object.entity.name else { continue }

            dict[name] = (dict[name] ?? 0) + 1
        }

        Logger.shared.logDebug("\(name) \(objects.count) objects: \(dict)", category: .coredata)

//        dump(objects)
    }

    static var savedCount = 0
    // MARK: NSManagedObjectContext saves
    @discardableResult
    func saveContext(file: StaticString = #file, line: UInt = #line) throws -> Bool {
        checkThread()
        Logger.shared.logDebug("\(self) saveContext called from \(file):\(line). hasChanges: \(context.hasChanges)",
                               category: .document)

        guard context.hasChanges else {
            Logger.shared.logDebug("DocumentManager.saveContext: no changes!", category: .document)
            return false
        }

        addLogLine(context.insertedObjects, name: "Inserted")
        addLogLine(context.deletedObjects, name: "Deleted")
        addLogLine(context.updatedObjects, name: "Updated")
        addLogLine(context.registeredObjects, name: "Registered")

        Self.savedCount += 1

        do {
            let inserted = context.insertedObjects.compactMap { ($0 as? Document)?.documentStruct }
            let updated = context.updatedObjects.compactMap { ($0 as? Document)?.documentStruct }
            let saved = Set(inserted + updated)
            let softDeleted = Set(saved.compactMap { object -> UUID? in
                return object.deletedAt == nil ? nil : object.id
            })
            let deleted = softDeleted.union(Set(context.deletedObjects.compactMap { ($0 as? Document)?.id }))

            let localTimer = BeamDate.now
            try CoreDataManager.save(context)
            Logger.shared.logDebug("[\(Self.savedCount)] CoreDataManager saved", category: .coredata, localTimer: localTimer)

            for noteSaved in saved {
                Self.notifyDocumentSaved(noteSaved)
            }

            for noteDeleted in deleted {
                Self.notifyDocumentDeleted(noteDeleted)
            }

            return true
        } catch let error as NSError {
            switch error.code {
            case 133021:
                // Constraint conflict
                Logger.shared.logError("Couldn't save context because of a constraint: \(error)", category: .coredata)
                logConstraintConflict(error)
            case 133020:
                // Saving a version of NSManagedObject which is outdated
                Logger.shared.logError("Couldn't save context because the object is outdated and more recent in CoreData: \(error)",
                                       category: .coredata)
                logMergeConflict(error)
            default:
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
            }

            throw error
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func logConstraintConflict(_ error: NSError) {
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
    private func logMergeConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSMergeConflict] else { return }

        for conflict in conflicts {
            let title = (conflict.sourceObject as? Document)?.title ?? ":( sourceObject Document Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
        }
    }

    // MARK: Validations
    internal func checkValidations(_ document: Document) throws {
        checkThread()
        guard document.deleted_at == nil else { return }

        Logger.shared.logDebug("checkValidations for \(document.titleAndId)", category: .documentDebug)
        try checkJournalDay(document)
        try checkDuplicateJournalDates(document)
        try checkDuplicateTitles(document)
    }

    private func checkJournalDay(_ document: Document) throws {
        checkThread()
        guard document.documentType == .journal else { return }
        guard String(document.journal_day).count != 8 else { return }

        let errString = "journal_day is \(document.journal_day) for \(document.titleAndId)"

        Logger.shared.logError(errString, category: .document)

        let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                       NSValidationObjectErrorKey: self]
        throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1003, userInfo: userInfo)
    }

    private func checkDuplicateJournalDates(_ document: Document) throws {
        checkThread()
        guard document.documentType == .journal else { return }
        guard String(document.journal_day).count == 8 else { return }

        let documents = (try? fetchAll(filters: [.journalDate(document.journal_day), .notId(document.id), .databaseId(document.database_id), .nonDeleted]).map { DocumentStruct(document: $0) }) ?? []

        if !documents.isEmpty {
            let errString = "Journal Date \(document.journal_day) for \(document.titleAndId) already used in \(documents.count) other documents: \(documents.map { $0.titleAndId })"

            Logger.shared.logError(errString, category: .document)

            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                           NSValidationObjectErrorKey: self,
                                           "documents": documents]

            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1004, userInfo: userInfo)
        }
    }

    private func checkDuplicateTitles(_ document: Document) throws {
        checkThread()
        let documents = (try? fetchAll(filters: [.title(document.title), .notId(document.id), .nonDeleted, .databaseId(document.database_id)]).map { DocumentStruct(document: $0) }) ?? []

        if !documents.isEmpty {
            let documentIds = documents.compactMap { $0.titleAndId }.joined(separator: "; ")
            let errString = "Title \(document.titleAndId) is already used in \(documents.count) other documents: \(documentIds)"

            Logger.shared.logError(errString, category: .document)

            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                           NSValidationObjectErrorKey: self,
                                           "documents": documents]

            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
        }
    }

    internal func checkVersion(_ document: Document, _ newVersion: Int64) throws {
        checkThread()
        // If document is deleted, we don't need to check version uniqueness
        guard document.deleted_at == nil else { return }

        let existingDocument = try? fetchWithId(document.id, includeDeleted: false)

        if let existingVersion = existingDocument?.version, existingVersion >= newVersion {
            let errString = "\(document.title): coredata version: \(existingVersion) should be < newVersion: \(newVersion)"
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString, NSValidationObjectErrorKey: self]
            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1002, userInfo: userInfo)
        }
    }

    // MARK: Shared
    // swiftlint:disable function_body_length
    func saveAndThrottle(_ documentStruct: DocumentStruct,
                         _ delay: Double = 1.0,
                         _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        checkThread()
        let document_id = documentStruct.id

        // This is not using `cancelPreviousThrottledAPICall` as we want to:
        // * use the semaphore on the whole `saveAndThrottle` method, to avoid RACE
        // * call the network completionHandler now so any previous calls are aware a previous network save has been cancelled
        Self.networkTasksSemaphore.wait()
        defer { Self.networkTasksSemaphore.signal() }

        /*
         We only want to discard previous throttled network tasks if they haven't started yet, else we need to let them
         run and complete, to make sure they store the previous checksum
         */
        if let tuple = Self.networkTasks[document_id] {
            if tuple.1 == false {
                Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): cancelling previous throttled network call",
                                       category: .documentNetwork)

                tuple.0.cancel()
                tuple.2?(.failure(DocumentManagerError.operationCancelled))
            } else {
                Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): not cancelling previous throttled network call",
                                       category: .documentNetwork)
            }
        } else {
            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): not previous throttled network call",
                                   category: .documentNetwork)
        }

        var networkTask: DispatchWorkItem!
        var networkTaskStarted = false

        networkTask = DispatchWorkItem {
            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): starting",
                                   category: .documentNetwork)

            guard !networkTask.isCancelled else {
                Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): cancelled",
                                       category: .documentNetwork)
                networkCompletion?(.failure(DocumentManagerError.operationCancelled))
                return
            }
            networkTaskStarted = true

            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): executing",
                                   category: .documentNetwork)

            let localTimer = BeamDate.now

            // We want to fetch back the document, to update it's previousChecksum
            // context.refresh(document, mergeChanges: false)
            let documentManager = DocumentManager()

            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): calling fetchWithId",
                                   category: .documentNetwork)

            var updatedDocument: Document?
            documentManager.saveDocumentQueue.sync {
                updatedDocument = try? documentManager.fetchWithId(documentStruct.id, includeDeleted: false)
            }

            guard let updatedDocument = updatedDocument else {
                Logger.shared.logWarning("Network task for \(documentStruct.titleAndId): document disappeared (deleted?), isCancelled: \(networkTask.isCancelled)",
                                         category: .coredata)
                networkCompletion?(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }

            let saveObject = DocumentStruct(document: updatedDocument)

            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): called fetchWithId. previousChecksum \(saveObject.previousChecksum ?? "-")",
                                   category: .documentNetwork)

            Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): calling network with \(updatedDocument.titleAndId) (refreshed object)",
                                   category: .documentNetwork)

            guard !networkTask.isCancelled else { return }

            let semaphore = DispatchSemaphore(value: 0)
            documentManager.saveDocumentStructOnAPI(saveObject) { result in
                networkCompletion?(result)

                Self.networkTasksSemaphore.wait()
                Self.networkTasks.removeValue(forKey: document_id)
                Self.networkTasksSemaphore.signal()

                Logger.shared.logDebug("Network task for \(updatedDocument.titleAndId): executed (inloop)",
                                       category: .documentNetwork,
                                       localTimer: localTimer)

                semaphore.signal()
            }
            semaphore.wait()

            Logger.shared.logDebug("Network task for \(updatedDocument.titleAndId): executed (outloop)",
                                   category: .documentNetwork)
        }

        if let tuple = Self.networkTasks[document_id] {
            if !tuple.0.isCancelled && tuple.1 == false {
                Logger.shared.logError("Network task for \(documentStruct.titleAndId): previous task not cancelled but not running!",
                                       category: .documentNetwork)
            }
        }

        Self.networkTasks[document_id] = (networkTask, networkTaskStarted, networkCompletion)
        // `asyncAfter` will not execute before `deadline` but might be executed later. It is not accurate.
        // TODO: use `Timer.scheduledTimer` or `perform:with:afterDelay`
        backgroundQueue.asyncAfter(deadline: .now() + delay, execute: networkTask)
        Logger.shared.logDebug("Network task for \(documentStruct.titleAndId): adding network task for later",
                               category: .documentNetwork)
    }
}

// MARK: - updates
extension DocumentManager {
    /// This publisher is triggered anytime we store a document in the DB. Note that it also happens when softDeleting a note
    static let documentSaved = PassthroughSubject<DocumentStruct, Never>()
    /// This publisher is triggered anytime we are completely removing a note from the DB. Soft delete do NOT call it though.
    static let documentDeleted = PassthroughSubject<UUID, Never>()

    private static var notificationLock = RWLock()
    private static var waitingSavedNotifications = [UUID: DocumentStruct]()
    private static var waitingDeletedNotifications = Set<UUID>()
    private static var notificationStatus = 1

    private static func notifyDocumentSaved(_ documentStuct: DocumentStruct) {
        if notificationEnabled {
            documentSaved.send(documentStuct)
        } else {
            notificationLock.write {
                waitingSavedNotifications[documentStuct.id] = documentStuct
            }
        }
    }

    private static func notifyDocumentDeleted(_ documentId: UUID) {
        if notificationEnabled {
            documentDeleted.send(documentId)
        } else {
            _ = notificationLock.write {
                waitingDeletedNotifications.insert(documentId)
            }
        }
    }

    static var notificationEnabled: Bool {
        notificationLock.read {
            notificationStatus > 0
        }
    }
    static func disableNotifications() {
        notificationLock.write {
            notificationStatus -= 1
        }
    }
    static func enableNotifications() {
        notificationLock.write {
            notificationStatus += 1
            assert(notificationStatus <= 1)
        }
        purgeNotifications()
    }

    private static func purgeNotifications() {
        guard notificationEnabled else { return }
        notificationLock.write {
            for saved in self.waitingSavedNotifications.values {
                Self.documentSaved.send(saved)
            }
            for deleted in self.waitingDeletedNotifications {
                Self.documentDeleted.send(deleted)
            }

            self.waitingSavedNotifications.removeAll()
            self.waitingDeletedNotifications.removeAll()
        }
    }
}

// For tests
extension DocumentManager {
    func create(title: String, deletedAt: Date?) -> DocumentStruct? {
        checkThread()
        var result: DocumentStruct?

        do {
            let document: Document = try create(id: UUID(), title: title, deletedAt: deletedAt)
            result = parseDocumentBody(document)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        return result
    }

    // From Document:
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    class func fetchRequest(filters: [DocumentFilter], sortingKey: SortingKey?) -> NSFetchRequest<Document> {
        let request = NSFetchRequest<Document>(entityName: "Document")

        var predicates: [NSPredicate] = []
        var defaultDB = true
        var deletionFilter = false

        for filter in filters {
            switch filter {
            case .allDatabases:
                defaultDB = false

            case let .databaseId(dbId):
                defaultDB = false
                predicates.append(NSPredicate(format: "database_id = %@",
                                              dbId as CVarArg))
            case let .notDatabaseId(dbId):
                defaultDB = false
                predicates.append(NSPredicate(format: "NOT database_id = %@",
                                              dbId as CVarArg))

            case let .notDatabaseIds(dbIds):
                defaultDB = false
                predicates.append(NSPredicate(format: "NOT (database_id IN %@)",
                                              dbIds))
            case let .id(id):
                predicates.append(NSPredicate(format: "id = %@",
                                              id as CVarArg))
            case let .notId(id):
                predicates.append(NSPredicate(format: "id != %@",
                                              id as CVarArg))
            case let .ids(ids):
                predicates.append(NSPredicate(format: "id IN %@", ids))

            case let .notIds(ids):
                predicates.append(NSPredicate(format: "NOT id IN %@", ids))

            case let .title(title):
                predicates.append(NSPredicate(format: "title ==[cd] %@",
                                              title))
            case let .titleMatch(title):
                predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg))
            case let .journalDate(journalDate):
                predicates.append(NSPredicate(format: "journal_day == %d",
                                              journalDate))
            case let .beforeJournalDate(journalDate):
                predicates.append(NSPredicate(format: "journal_day < %d",
                                              journalDate))
            case let .nonFutureJournalDate(journalDate):
                predicates.append(NSPredicate(format: "journal_day <= \(journalDate)"))

            case let .type(type):
                predicates.append(NSPredicate(format: "document_type = %ld", type.rawValue))

            case .nonDeleted:
                deletionFilter = true
                predicates.append(NSPredicate(format: "deleted_at == nil"))

            case .deleted:
                deletionFilter = true
                predicates.append(NSPredicate(format: "deleted_at != nil"))

            case .includeDeleted:
                deletionFilter = true

            case let .updatedSince(date):
                predicates.append(NSPredicate(format: "updated_at >= %@", date as CVarArg))

            case let .limit(limit):
                request.fetchLimit = limit

            case let .offset(offset):
                request.fetchOffset = offset
            }
        }

        if !deletionFilter {
            // if there is no deletion filter, only search for non deleted notes by default:
            predicates.append(NSPredicate(format: "deleted_at == nil"))
        }

        if defaultDB {
            predicates.append(NSPredicate(format: "database_id = %@",
                                          DatabaseManager.defaultDatabase.id as CVarArg))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        if let sortingKey = sortingKey {
            request.sortDescriptors = sortDescriptorsFor(sortingKey)
        }

        return request
    }

    /// Slower than `deleteBatchWithPredicate` but I can't get `deleteBatchWithPredicate`
    /// to properly propagate changes to other contexts :(
    func deleteAll(databaseId: UUID?) throws {
        checkThread()

        do {
            let filters: [DocumentFilter] = {
                if let databaseId = databaseId {
                    return [.databaseId(databaseId), .includeDeleted]
                } else {
                    return [.includeDeleted, .allDatabases]
                }
            }()
            let allDocuments = try fetchAll(filters: filters)
            for document in allDocuments {
                context.delete(document)
            }

            if !allDocuments.isEmpty {
                try saveContext()
            }
        } catch {
            Logger.shared.logError("DocumentManager.deleteAll failed: \(error)", category: .document)
            throw error
        }
    }

    func softDeleteAll(databaseId: UUID?) throws {
        checkThread()

        do {
            let filters: [DocumentFilter] = {
                if let databaseId = databaseId {
                    return [.databaseId(databaseId)]
                } else {
                    return [.allDatabases]
                }
            }()

            let documentManager = DocumentManager()

            let allDocuments: [DocumentStruct] = (try documentManager.fetchAll(filters: filters)).compactMap { document in
                var documentStruct = DocumentStruct(document: document)
                documentStruct.version += 1
                documentStruct.deletedAt = documentStruct.deletedAt ?? BeamDate.now

                let semaphore = DispatchSemaphore(value: 0)

                // TODO: should be optimized but this isn't called often. We should save all documentstruct at once instead
                documentManager.save(documentStruct, false, nil) { _ in
                    semaphore.signal()
                }

                semaphore.wait()

                return documentStruct
            }

            if !allDocuments.isEmpty {
                let semaphore = DispatchSemaphore(value: 0)

                try documentManager.saveOnBeamObjectsAPI(allDocuments) { _ in
                    semaphore.signal()
                }

                semaphore.wait()
            }
        } catch {
            Logger.shared.logError("DocumentManager.softDeleteAll failed: \(error)", category: .document)
            throw error
        }
    }

    func create(id: UUID, title: String? = nil, deletedAt: Date?, shouldSaveContext: Bool = true) throws -> Document {
        checkThread()
        let document = Document(context: context)
        document.id = id
        document.database_id = DatabaseManager.defaultDatabase.id
        document.version = 0
        document.document_type = DocumentType.note.rawValue
        document.deleted_at = deletedAt
        if let title = title {
            document.title = title
        }

        try checkValidations(document)
        if shouldSaveContext {
            try saveContext()
        }

        return document
    }

    func count(filters: [DocumentFilter] = []) -> Int {
        checkThread()
        // Fetch existing if any
        let fetchRequest = DocumentManager.fetchRequest(filters: filters, sortingKey: nil)

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't count: \(error)", category: .coredata)
        }

        return 0
    }

    enum SortingKey {
        /// Ascending = true, Descending = false
        case title(Bool)
        /// Ascending = true, Descending = false
        case journal_day(Bool)
        case journal(Bool)
        case updatedAt(Bool)
    }

    internal class func sortDescriptorsFor(_ key: SortingKey) -> [NSSortDescriptor] {
        switch key {
        case .title(let ascencing):
            return [NSSortDescriptor(key: "title", ascending: ascencing, selector: #selector(NSString.caseInsensitiveCompare))]

        case let .journal_day(ascending):
            return [NSSortDescriptor(key: "journal_day", ascending: ascending)]

        case let .journal(ascending):
            return  [NSSortDescriptor(key: "journal_day", ascending: ascending),
                     NSSortDescriptor(key: "created_at", ascending: ascending)]

        case let .updatedAt(ascending):
            return [NSSortDescriptor(key: "updated_at",
                              ascending: ascending)]
        }
    }

    func fetchFirst(filters: [DocumentFilter] = [],
                    sortingKey: SortingKey? = nil) throws -> Document? {
        checkThread()
        return try fetchAll(filters: [.limit(1)] + filters,
                            sortingKey: sortingKey).first
    }

    func fetchAll(filters: [DocumentFilter] = [], sortingKey: SortingKey? = nil) throws -> [Document] {
        checkThread()
        let fetchRequest = DocumentManager.fetchRequest(filters: filters, sortingKey: sortingKey)

        let fetchedDocuments = try context.fetch(fetchRequest)
        return fetchedDocuments
    }

    func fetchAllNames(filters: [DocumentFilter], sortingKey: SortingKey? = nil) -> [String] {
        checkThread()
        let fetchRequest = DocumentManager.fetchRequest(filters: filters, sortingKey: sortingKey)
        fetchRequest.propertiesToFetch = ["title"]

        do {
            let fetchedDocuments = try context.fetch(fetchRequest)
            return fetchedDocuments.compactMap { $0.title }
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't fetch all: \(error)", category: .coredata)
        }

        return []
    }

    func fetchAllWithIds(_ ids: [UUID]) throws -> [Document] {
        checkThread()
        return try fetchAll(filters: [.nonDeleted, .ids(ids)])
    }

    func fetchWithId(_ id: UUID, includeDeleted: Bool) throws -> Document? {
        checkThread()

        let filters: [DocumentFilter] = includeDeleted ? [.id(id), .includeDeleted, .allDatabases] : [.id(id), .allDatabases]
        return try fetchFirst(filters: filters)
    }

    func fetchOrCreate(_ id: UUID, title: String, deletedAt: Date?, shouldSaveContext: Bool = true) throws -> Document {
        checkThread()
        let document = try ((try? fetchWithId(id, includeDeleted: false)) ?? (try create(id: id, title: title, deletedAt: deletedAt, shouldSaveContext: shouldSaveContext)))
        return document
    }

    func fetchOrCreate(_ title: String, id: UUID? = nil, deletedAt: Date?) throws -> Document {
        checkThread()
        let document = try ((try? fetchWithTitle(title)) ?? (try create(id: id ?? UUID(), title: title, deletedAt: deletedAt)))
        return document
    }

    func fetchWithTitle(_ title: String) throws -> Document? {
        checkThread()
        return try fetchFirst(filters: [.title(title), .nonDeleted], sortingKey: .title(true))
    }

    func fetchWithJournalDate(_ date: String) -> Document? {
        checkThread()
        let date = JournalDateConverter.toInt(from: date)
        return try? fetchFirst(filters: [.journalDate(date)])
    }

    func fetchAllWithTitleMatch(title: String,
                                limit: Int) throws -> [Document] {
        checkThread()
        return try fetchAll(filters: [.titleMatch(title), .limit(limit)],
                            sortingKey: .title(true))
    }
}
