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
        case .multipleErrors(let errors):
            return "Multiple errors: \(errors)"
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
    case nonFutureJournalDate(Int64)
    case type(DocumentType)
    case nonDeleted ///< filter out deleted notes (the default if nothing is explicitely requested)
    case deleted ///< filter out non delete notes
    case includeDeleted ///< don't filter out anything
    case updatedSince(Date)

    case limit(Int)
    case offset(Int)

}

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public class DocumentManager: NSObject {
    var coreDataManager: CoreDataManager
    var context: NSManagedObjectContext
    static let backgroundQueue = DispatchQueue(label: "DocumentManager backgroundQueue", qos: .default)
    var backgroundQueue: DispatchQueue { Self.backgroundQueue }

    let saveDocumentQueue = OperationQueue()
    var saveOperations: [UUID: BlockOperation] = [:]
    var saveDocumentPromiseCancels: [UUID: () -> Void] = [:]

    static var networkTasks: [UUID: (DispatchWorkItem, ((Swift.Result<Bool, Error>) -> Void)?)] = [:]
    static var networkTasksSemaphore = DispatchSemaphore(value: 1)

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        context = Thread.isMainThread ? self.coreDataManager.mainContext : self.coreDataManager.persistentContainer.newBackgroundContext()
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
    func loadById(id: UUID) -> DocumentStruct? {
        guard let document = try? self.fetchWithId(id) else { return nil }
        return parseDocumentBody(document)
    }

    func fetchOrCreate(title: String) -> DocumentStruct? {
        do {
            let document = try fetchOrCreateWithTitle(title)
            return parseDocumentBody(document)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
            return nil
        }
    }

    func allDocumentsTitles(includeDeletedNotes: Bool) -> [String] {
        return fetchAllNames(filters: includeDeletedNotes ? [.includeDeleted] : [])
    }

    func allDocumentsIds(includeDeletedNotes: Bool) -> [UUID] {
        let result = (try? fetchAll(filters: includeDeletedNotes ? [.includeDeleted] : [])) ?? []
        return result.map { $0.id }
    }

    func loadDocByTitleInBg(title: String) -> DocumentStruct? {
        guard let document = try? fetchWithTitle(title) else { return nil }
        return parseDocumentBody(document)
    }

    func loadDocumentByTitle(title: String) -> DocumentStruct? {
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

    func loadDocumentById(id: UUID) -> DocumentStruct? {
        guard let document = try? fetchWithId(id) else { return nil }
        return parseDocumentBody(document)
    }

    func loadDocumentsById(ids: [UUID]) -> [DocumentStruct] {
        do {
            return try fetchAllWithIds(ids).compactMap {
                parseDocumentBody($0)
            }
        } catch { return [] }
    }

    func loadDocumentWithJournalDate(_ date: String) -> DocumentStruct? {
        guard let document = fetchWithJournalDate(date) else { return nil }
        return parseDocumentBody(document)
    }

    func loadDocumentsWithType(type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [DocumentStruct] {
        do {
            return try fetchWithTypeAndLimit(type,
                                             limit,
                                             fetchOffset).compactMap { (document) -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func documentsWithTitleMatch(title: String) -> [DocumentStruct] {
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
        do {
            return try fetchAllWithTitleMatch(title: title, limit: limit)
                .compactMap { document -> DocumentStruct? in
                parseDocumentBody(document)
            }
        } catch { return [] }
    }

    func loadAllWithLimit(_ limit: Int = 4, sortingKey: SortingKey? = nil) -> [DocumentStruct] {
        do {
            return try fetchAll(filters: [.limit(limit)], sortingKey: sortingKey).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
                }
        } catch { return [] }
    }

    func loadAll() -> [DocumentStruct] {
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
                       previousData: document.beam_api_data,
                       previousChecksum: document.beam_api_checksum,
                       version: document.version,
                       isPublic: document.is_public,
                       beamObjectPreviousChecksum: document.beam_object_previous_checksum,
                       journalDate: document.document_type == DocumentType.journal.rawValue ? JournalDateConverter.toString(from: document.journal_day) : nil
        )
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

    func isEqual(_ document: Document, to documentStruct: DocumentStruct) -> Bool {
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
            document.beam_object_previous_checksum == documentStruct.previousChecksum &&
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
        Logger.shared.logDebug("DocumentManager.saveContext called from \(file):\(line). \(context.hasChanges ? "changed" : "unchanged")", category: .document)

        guard context.hasChanges else {
            return false
        }

        addLogLine(context.insertedObjects, name: "Inserted")
        addLogLine(context.deletedObjects, name: "Deleted")
        addLogLine(context.updatedObjects, name: "Updated")
        addLogLine(context.registeredObjects, name: "Registered")

        Self.savedCount += 1

        do {
            let localTimer = BeamDate.now
            try CoreDataManager.save(context)
            Logger.shared.logDebug("[\(Self.savedCount)] CoreDataManager saved", category: .coredata, localTimer: localTimer)
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
            let title = (conflict.sourceObject as? Document)?.title ?? ":( Document Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
        }
    }

    // MARK: Validations
    internal func checkValidations(_ document: Document) throws {
        guard document.deleted_at == nil else { return }

        Logger.shared.logDebug("checkValidations for \(document.titleAndId)", category: .documentDebug)
        try checkJournalDay(document)
        try checkDuplicateJournalDates(document)
        try checkDuplicateTitles(document)
    }

    private func checkJournalDay(_ document: Document) throws {
        guard document.documentType == .journal else { return }
        guard String(document.journal_day).count != 8 else { return }

        let errString = "journal_day is \(document.journal_day) for \(document.titleAndId)"

        Logger.shared.logError(errString, category: .document)

        let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString,
                                       NSValidationObjectErrorKey: self]
        throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1003, userInfo: userInfo)
    }

    private func checkDuplicateJournalDates(_ document: Document) throws {
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
        // If document is deleted, we don't need to check version uniqueness
        guard document.deleted_at == nil else { return }

        let existingDocument = try? fetchWithId(document.id)

        if let existingVersion = existingDocument?.version, existingVersion >= newVersion {
            let errString = "\(document.title): coredata version: \(existingVersion) should be < newVersion: \(newVersion)"
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

            self.backgroundQueue.async {
                // We want to fetch back the document, to update it's previousChecksum
                // context.refresh(document, mergeChanges: false)
                let documentManager = DocumentManager()
                guard let updatedDocument = try? documentManager.fetchWithId(documentStruct.id) else {
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

extension DocumentManager {
    public override var description: String { "Beam.DocumentManager" }
}

// MARK: - updates
extension DocumentManager {
    /// Use this to have updates when the underlaying CD object `Document` changes
    func onDocumentChange(_ documentStruct: DocumentStruct,
                          completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        Logger.shared.logDebug("onDocumentChange called for \(documentStruct.titleAndId)", category: .documentNotification)

        var documentId = documentStruct.id
        let cancellable = NotificationCenter.default
            .publisher(for: .documentUpdate)
            .sink { notification in
                let documentManager = DocumentManager()
                guard let updatedDocuments = notification.userInfo?["updatedDocuments"] as? [DocumentStruct] else {
                    return
                }

                for document in updatedDocuments {

                    /*
                     I used to prevent calling `completionHandler` when that condition was true:

                     `if let documentManager = notification.object as? DocumentManager, documentManager == self { return }`

                     to avoid the same DocumentManager to return its own saved update.

                     But we have legit scenarios when such is happening, for example when there is an API conflict,
                     and the manager fetch, merge and resave that merged object.

                     We need the UI to be updated about such to reflect the merge.
                     */

                    if document.title == documentStruct.title &&
                        document.databaseId == documentStruct.databaseId &&
                        document.id != documentId {

                        /*
                         When a document is deleted and overwritten because of a title conflict, we want to let
                         the editor know to update the editor UI with the new document.

                         However when going on the "see all notes" debug window, and forcing a document refresh,
                         we don't want the editor UI to change.
                         */

                        guard let coreDataDocument = try? documentManager.fetchWithId(documentId) else {
                            Logger.shared.logDebug("onDocumentChange for \(document.titleAndId) (new id)",
                                                   category: .documentNotification)
                            documentId = document.id
                            completionHandler(document)
                            return
                        }

                        if documentStruct.deletedAt == nil, coreDataDocument.deleted_at != documentStruct.deletedAt {
                            Logger.shared.logDebug("onDocumentChange for \(document.titleAndId) (new id)",
                                                   category: .documentNotification)
                            documentId = document.id
                            completionHandler(document)
                        } else {
                            Logger.shared.logDebug("onDocumentChange: no notification for \(document.titleAndId) (new id)",
                                                   category: .documentNotification)
                        }
                    } else if document.id == documentId {
                        Logger.shared.logDebug("onDocumentChange for \(document.titleAndId)",
                                               category: .documentNotification)
                        completionHandler(document)
                    } else if document.title == documentStruct.title {
                        Logger.shared.logDebug("onDocumentChange for \(document.titleAndId) but not detected. Called with \(documentStruct.titleAndId), {\(documentId)}",
                                               category: .documentNotification)
                    }
                }
            }
        return cancellable
    }

    func onDocumentDelete(_ documentStruct: DocumentStruct,
                          completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        Logger.shared.logDebug("onDocumentDelete called for \(documentStruct.titleAndId)", category: .documentDebug)

        let cancellable = NotificationCenter.default
            .publisher(for: .documentUpdate)
            .sink { notification in
                // Skip notification coming from this manager
                if let documentManager = notification.object as? DocumentManager, documentManager == self {
                    return
                }

                if let deletedDocuments = notification.userInfo?["deletedDocuments"] as? [DocumentStruct] {
                    for document in deletedDocuments where document.id == documentStruct.id {
                        Logger.shared.logDebug("notification for \(document.titleAndId)", category: .document)
                        try? GRDBDatabase.shared.remove(noteTitled: document.title)
                        completionHandler(document)
                    }
                }
            }
        return cancellable
    }
}

// For tests
extension DocumentManager {
    func create(title: String) -> DocumentStruct? {
        var result: DocumentStruct?

        do {
            let document: Document = try create(id: UUID(), title: title)
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

            try saveContext()
        } catch {
            Logger.shared.logError("DocumentManager.deleteAll failed: \(error)", category: .document)
            throw error
        }
    }

    func create(id: UUID, title: String? = nil) throws -> Document {
        let document = Document(context: context)
        document.id = id
        document.database_id = DatabaseManager.defaultDatabase.id
        document.version = 0
        document.document_type = DocumentType.note.rawValue
        if let title = title {
            document.title = title
        }

        try checkValidations(document)
        try saveContext()

        return document
    }

    func count(filters: [DocumentFilter] = []) -> Int {
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
        case title(Bool) ///< Ascending = true, Descending = false
        case journal_day(Bool) ///< Ascending = true, Descending = false
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
        return try fetchAll(filters: [.limit(1)] + filters,
                            sortingKey: sortingKey).first
    }

    func fetchAll(filters: [DocumentFilter] = [], sortingKey: SortingKey? = nil) throws -> [Document] {
        let fetchRequest = DocumentManager.fetchRequest(filters: filters, sortingKey: sortingKey)

        let fetchedDocuments = try context.fetch(fetchRequest)
        return fetchedDocuments
    }

    func fetchAllNames(filters: [DocumentFilter], sortingKey: SortingKey? = nil) -> [String] {
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
        try fetchAll(filters: [.nonDeleted, .ids(ids)])
    }

    func fetchWithId(_ id: UUID) throws -> Document? {
        try fetchFirst(filters: [.id(id), .includeDeleted, .allDatabases])
    }

    func fetchOrCreateWithId(_ id: UUID) throws -> Document {
        let document = try ((try? fetchWithId(id)) ?? (try create(id: id)))
        return document
    }

    func fetchWithTitle(_ title: String) throws -> Document? {
        return try fetchFirst(filters: [.title(title)], sortingKey: .title(true))
    }

    func fetchOrCreateWithTitle(_ title: String) throws -> Document {
        try ((try? fetchFirst(filters: [.title(title)])) ?? (try create(id: UUID(), title: title)))
    }

    func fetchWithJournalDate(_ date: String) -> Document? {
        let date = JournalDateConverter.toInt(from: date)
        return try? fetchFirst(filters: [.journalDate(date)])
    }

    func fetchWithTypeAndLimit(_ type: DocumentType,
                               _ limit: Int,
                               _ fetchOffset: Int) throws -> [Document] {

        let today = BeamNoteType.titleForDate(BeamDate.now)
        let todayInt = JournalDateConverter.toInt(from: today)

        return try fetchAll(filters: [.type(type), .nonFutureJournalDate(todayInt), .limit(limit), .offset(fetchOffset)], sortingKey: .journal(false))
    }

    func fetchAllWithTitleMatch(title: String,
                                limit: Int) throws -> [Document] {
        return try fetchAll(filters: [.titleMatch(title), .limit(limit)],
                            sortingKey: .title(true))
    }
}
