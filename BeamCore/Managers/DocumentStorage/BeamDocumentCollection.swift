//
//  BeamDocumentCollection.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/04/2022.
//

import Foundation
import Combine
import GRDB
import BeamCore

extension BeamDocumentSource {
    public var sourceId: String { Self.sourceId }
}

public enum DocumentFilter {
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
    case updatedSince(Date)
    case updatedBetween(Date, Date)
    case isPublic(Bool)

    case limit(Int, offset: Int?)
}

public enum DocumentSortingKey {
    /// Ascending = true, Descending = false
    case title(Bool)
    /// Ascending = true, Descending = false
    case journal_day(Bool)
    case journal(Bool)
    case updatedAt(Bool)
}

public enum BeamDocumentCollectionError: Error {
    case noAccount
    case databasePathNotFound

    case migrationFailed

    case missingSource
    case invalidJournalDay(BeamDocument)
    case duplicateJournalEntry(BeamDocument)
    case duplicateTitle(BeamDocument)
    case failedVersionCheck(BeamDocument, existingVersion: BeamVersion, newVersion: BeamVersion)
    case databaseError
    case deletedDocumentsCantBeSavedLocally

}

public class BeamDocumentCollection: GRDBHandler, LegacyAutoImportDisabler {
    weak public private(set) var holder: BeamManagerOwner?
    var database: BeamDatabase? {
        holder as? BeamDatabase
    }

    public override var tableNames: [String] { [BeamDocument.databaseTableName] }

    public required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    // MARK: Migration
    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("creation") { db in
            try db.create(table: BeamDocument.databaseTableName) { table in
                table.column("id", .blob).notNull().indexed().primaryKey()
                table.column("source", .text).notNull()
                table.column("title", .text).notNull().indexed()
                table.column("createdAt", .date).notNull()
                table.column("updatedAt", .date).notNull()
                table.column("data", .blob).notNull()
                table.column("documentType", .integer).notNull()
                table.column("version", .integer).notNull()
                table.column("isPublic", .boolean).notNull()
                table.column("journalDate", .integer)
            }
        }

        migrator.registerMigration("BeamDocumentCollection.addRealVersion") { db in
            let documents = try BeamDocument.fetchAll(db)
            try db.drop(table: BeamDocument.databaseTableName)
            try db.create(table: BeamDocument.databaseTableName) { table in
                table.column("id", .blob).notNull().indexed().primaryKey()
                table.column("source", .text).notNull()
                table.column("title", .text).notNull().indexed()
                table.column("createdAt", .date).notNull()
                table.column("updatedAt", .date).notNull()
                table.column("data", .blob).notNull()
                table.column("documentType", .integer).notNull()
                table.column("version", .blob).notNull()
                table.column("isPublic", .boolean).notNull()
                table.column("journalDate", .integer)
            }
            for document in documents {
                _ = try document.inserted(db)
            }
        }
    }

    // MARK: Primary access to the database
    // MARK: Note creation
    public enum CreationType {
        case note(title: String)
        case journal(date: Date)
    }

    public func fetchOrCreate(_ source: BeamDocumentSource, id: UUID, type: CreationType, _ creator: @escaping (inout BeamNote) throws -> Void = { _ in }) throws -> BeamDocument {
        return try run {
            guard let document = try self.fetchFirst(filters: [.id(id)], sortingKey: nil) else {
                return try self.create(source, id: id, type: type, creator)
            }
            return document
        }
    }

    public func fetchOrCreate(_ source: BeamDocumentSource, type: CreationType, _ creator: @escaping (inout BeamNote) throws -> Void = { _ in }) throws -> BeamDocument {
        return try run {
            var filters: [DocumentFilter]
            switch type {
            case .note(let title):
                filters = [.title(title)]
            case .journal(let date):
                let t = JournalDateConverter.toInt(from: BeamNoteType.journalForDate(date).journalDateString ?? "")
                filters = [.journalDate(t)]
            }

            guard let document = try self.fetchFirst(filters: filters, sortingKey: .title(true)) else {
                return try self.create(source, id: UUID(), type: type, creator)
            }
            return document
        }
    }

    public func delete(_ source: BeamDocumentSource, filters: [DocumentFilter]) throws {
        var toNotify = [BeamDocument]()
        _ = try write { db in
            toNotify = try self.fetch(filters: filters).map({ originalDocument in
                var deletedDocument = originalDocument
                deletedDocument.deletedAt = BeamDate.now
                deletedDocument.updatedAt = BeamDate.now
                return deletedDocument
            })
            try Self.fetchRequest(filters: filters, sortingKey: nil).deleteAll(db)
        }

        toNotify.forEach { Self.notifyDocumentDeleted(source, $0) }
    }

    public func update(_ source: BeamDocumentSource, filters: [DocumentFilter], _ updater: @escaping (inout BeamDocument) throws -> Void) throws {
        var toNotify = [BeamDocument]()
        try write { db in
            try Self.fetchRequest(filters: filters, sortingKey: nil)
                .fetchAll(db)
                .forEach({ document in
                    var document = document
                    document.source = source.sourceId
                    try document.updateChanges(db, with: {
                            try updater(&$0)
                        try self.checkValidations($0)
                        toNotify.append($0)
                    })
                })
        }
        toNotify.forEach { Self.notifyDocumentSaved($0) }
    }

    public func save(_ source: BeamDocumentSource, _ document: BeamDocument, indexDocument: Bool, autoIncrementVersion: Bool = true) throws -> BeamDocument {
        var doc = document
        doc.source = source.sourceId
        if autoIncrementVersion {
            doc.version = doc.version.incremented()
        }
        try checkValidations(doc)

        let result = try write { db in
            return try doc.saved(db)
        }
        if indexDocument {
            self.indexDocument(doc)
        }
        Self.notifyDocumentSaved(result)

        return result
    }

    func indexDocument(_ document: BeamDocument) {
        BeamNote.indexingQueue.addOperation {
            let decoder = BeamJSONDecoder()
            do {
                let note = try decoder.decode(BeamNote.self, from: document.data)
                try BeamData.shared.noteLinksAndRefsManager?.append(note: note)
            } catch {
                Logger.shared.logError("Error while trying to index synced note '\(document.title)' [\(document.id)]: \(error)", category: .document)
            }
        }
    }

    public func count(filters: [DocumentFilter] = []) throws -> Int {
        return try read { try Self.fetchRequest(filters: filters, sortingKey: nil).fetchCount($0) }
    }

    public func fetch(filters: [DocumentFilter] = [], sortingKey: DocumentSortingKey? = nil) throws -> [BeamDocument] {
        return try read { try Self.fetchRequest(filters: filters, sortingKey: sortingKey).fetchAll($0).map({ document in
            var doc = document
            doc.database = self.database
            return doc
        }) }
    }

    public func fetchTitles(filters: [DocumentFilter], sortingKey: DocumentSortingKey? = nil) throws -> [String] {
        try read {
            try Self.fetchRequest(filters: filters, sortingKey: sortingKey)
            .select(BeamDocument.Columns.title)
            .asRequest(of: String.self)
            .fetchAll($0)
        }
    }

    public func fetchIds(filters: [DocumentFilter], sortingKey: DocumentSortingKey? = nil) throws -> [UUID] {
        try read {
            try Self.fetchRequest(filters: filters, sortingKey: sortingKey)
            .select(BeamDocument.Columns.id)
            .asRequest(of: UUID.self)
            .fetchAll($0)
        }
    }

    // MARK: Generic fetch requests
    //
    private class func fetchRequest(filters: [DocumentFilter], sortingKey: DocumentSortingKey?) ->  QueryInterfaceRequest<BeamDocument> {
        var request = BeamDocument.all()

        for filter in filters {
            switch filter {
            case let .id(id):
                request = request.filter(BeamDocument.Columns.id == id)
            case let .notId(id):
                request = request.filter(BeamDocument.Columns.id != id)
            case let .ids(ids):
                request = request.filter(ids.contains(BeamDocument.Columns.id))

            case let .notIds(ids):
                request = request.filter(!ids.contains(BeamDocument.Columns.id))

            case let .title(title):
                request = request.filter(BeamDocument.Columns.title.lowercased == title.lowercased())
            case let .titleMatch(title):
                request = request.filter(BeamDocument.Columns.title.lowercased.like("%\(title.lowercased())%"))
            case let .journalDate(journalDate):
                request = request.filter(BeamDocument.Columns.journalDate == journalDate)
            case let .beforeJournalDate(journalDay):
                request = request.filter(BeamDocument.Columns.journalDate < journalDay)
            case let .nonFutureJournalDate(journalDay):
                request = request.filter(BeamDocument.Columns.journalDate <= journalDay)

            case let .type(type):
                request = request.filter(BeamDocument.Columns.documentType == type)

            case let .updatedSince(date):
                request = request.filter(BeamDocument.Columns.updatedAt >= date)

            case let .updatedBetween(date0, date1):
                request = request.filter(BeamDocument.Columns.updatedAt >= date0 && BeamDocument.Columns.updatedAt <= date1)

            case let .limit(limit, offset: offset):
                request = request.limit(limit, offset: offset)
            case let .isPublic(isPublic):
                request = request.filter(BeamDocument.Columns.isPublic == isPublic)
            }
        }

        if let sortingKey = sortingKey {
            request = applySortDescriptors(sortingKey, to: request)
        }

        return request
    }

    private class func applySortDescriptors(_ key: DocumentSortingKey, to request: QueryInterfaceRequest<BeamDocument>) -> QueryInterfaceRequest<BeamDocument> {
        switch key {
        case .title(let ascending):
            let sortingKey = BeamDocument.Columns.title.lowercased
            return request.order(ascending ? sortingKey.asc : sortingKey.desc)

        case let .journal_day(ascending):
            let sortingKey = BeamDocument.Columns.journalDate
            return request.order(ascending ? sortingKey.asc : sortingKey.desc)

        case let .journal(ascending):
            let sortingKey1 = BeamDocument.Columns.journalDate
            let sortingKey2 = BeamDocument.Columns.createdAt
            return request.order(ascending ? sortingKey1.asc : sortingKey1.desc).order(ascending ? sortingKey2.asc : sortingKey2.desc)

        case let .updatedAt(ascending):
            let sortingKey = BeamDocument.Columns.updatedAt
            return request.order(ascending ? sortingKey.asc : sortingKey.desc)
        }
    }

    // MARK: Private Creation
    private func create(_ source: BeamDocumentSource,
                        id: UUID,
                        type: CreationType,
                        _ initer: @escaping (inout BeamNote) throws -> Void = { _ in }) throws -> BeamDocument {
        var note: BeamNote
        switch type {
        case .journal(date: let date):
            note = BeamNote(journalDate: date)
        case .note(title: let title):
            note = try BeamNote(title: title)
        }

        note.id = id
        note.owner = database

        try initer(&note)

        let encoder = JSONEncoder()
        let noteData = try encoder.encode(note)

        var document = BeamDocument(id: id,
                                    source: source,
                                    database: database,
                                    title: note.title,
                                    createdAt: BeamDate.now,
                                    updatedAt: BeamDate.now,
                                    deletedAt: nil,
                                    data: noteData,
                                    documentType: note.type.isJournal ? .journal : .note,
                                    version: note.version,
                                    isPublic: note.publicationStatus.isPublic,
                                    journalDate: JournalDateConverter.toInt(from: note.type.journalDateString ?? "0")
        )

        try checkValidations(document)
        do {
            try write { try document.insert($0) }
        } catch {
            Logger.shared.logError("Error creating document \(document) for note \(note): \(error)", category: .document)
        }
        Self.notifyDocumentSaved(document)
        return document
    }

    // MARK: Tracking changes:
    func observe(_ filters: [DocumentFilter], _ sortingKey: DocumentSortingKey?, scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main)) -> DatabasePublishers.Value<[BeamDocument]> {
        self.track(filters: { db in
            try Self.fetchRequest(filters: filters, sortingKey: sortingKey).fetchAll(db)
        }, scheduling: scheduler)
    }

    func observeIds(_ filters: [DocumentFilter], _ sortingKey: DocumentSortingKey?, scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main)) -> DatabasePublishers.Value<[UUID]> {
        self.track(filters: { db in
            try Self.fetchRequest(filters: filters, sortingKey: sortingKey)
                .select(BeamDocument.Columns.id)
                .asRequest(of: UUID.self)
                .fetchAll(db)
        }, scheduling: scheduler)
    }

    func observeTitles(_ filters: [DocumentFilter], _ sortingKey: DocumentSortingKey?, scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main)) -> DatabasePublishers.Value<[String]> {
        self.track(filters: { db in
            try Self.fetchRequest(filters: filters, sortingKey: sortingKey)
                .select(BeamDocument.Columns.title)
                .asRequest(of: String.self)
                .fetchAll(db)
        }, scheduling: scheduler)
    }
}

extension BeamDocumentCollection: BeamManager {
    public static var id = UUID()
    public static var name = "BeamDocumentCollection"
}

extension BeamManagerOwner {
    public var collection: BeamDocumentCollection? {
        try? manager(BeamDocumentCollection.self)
    }
}
