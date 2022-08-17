//
//  BeamDocument.swift
//  Beam
//
//  Created by Sebastien Metrot on 10/05/2022.
//

import Foundation
import GRDB
import BeamCore

/*
 When changing this, you *must* let backend know.
 There is are schema validators to update.
 */
public enum DocumentType: Int16, Codable {
    case journal
    case note
    case tabGroup
}

public struct BeamDocument {
    public var id: UUID = .null
    public var source: String = "?"
    public weak var database: BeamDatabase? {
        didSet {
            databaseId = database?.id ?? nil
        }
    }
    public private(set) var databaseId: UUID?
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var data: Data
    public var documentType: DocumentType {
        didSet {
            if documentType != .journal {
                journalDate = 0
            }
            if documentType != .tabGroup {
                tabGroupId = nil
            }
        }
    }
    public var version = BeamVersion()
    public var isPublic: Bool = false

    public var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }
    public var journalDate: Int64 {
        didSet {
            assert((journalDate == 0 && documentType == .note) || (journalDate != 0 && documentType == .journal))
        }
    }

    /// Only for document of type .tabGroup
    public var tabGroupId: UUID?

    public var collection: BeamDocumentCollection? {
        database?.collection
    }

    public init(id: UUID,
                source: BeamDocumentSource,
                database: BeamDatabase?,
                title: String,
                createdAt: Date,
                updatedAt: Date,
                deletedAt: Date? = nil,
                data: Data,
                documentType: DocumentType,
                version: BeamVersion,
                isPublic: Bool,
                journalDate: Int64,
                tabGroupId: UUID? = nil) {
        self.id = id
        self.source = source.sourceId
        self.database = database
        self.databaseId = database?.id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.data = data
        self.documentType = documentType
        self.version = version
        self.isPublic = isPublic
        self.journalDate = journalDate
        self.tabGroupId = tabGroupId
    }

    public var uuidString: String {
        id.uuidString.lowercased()
    }

    public var titleAndId: String {
        "\(title) {\(id)} v\(version)\(deletedAt != nil ? " [DELETED]" : "")"
    }

    public var isEmpty: Bool {
        do {
            let beamNote = try BeamNote.instanciateNote(self,
                                                        keepInMemory: false,
                                                        decodeChildren: true)
            return beamNote.isEntireNoteEmpty()
        } catch {
            Logger.shared.logError("Can't decode Document \(titleAndId): \(error.localizedDescription)",
                                   category: .document)
            Logger.shared.logError("data size: \(data.count), data: \(data.asString ?? "-")",
                                   category: .document)
        }

        return false
    }

    public func copy() -> BeamDocument {
        BeamDocument(document: self)
    }

    public func copy(to: BeamDatabase) -> BeamDocument {
        var newDoc = BeamDocument(document: self)
        newDoc.database = to

        return newDoc
    }
}

public extension BeamDocument {
    // Used for encoding this into BeamObject. Update `encode` and `init()` when adding values here
    enum CodingKeys: String, CodingKey {
        case id
        case databaseId
        case source
        case title
        case createdAt
        case updatedAt
        case deletedAt
        case data
        case documentType
        case journalDate
        case tabGroupId
        case isPublic
        case version
        case formatVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try Self.checkFormatVersion(try container.decodeIfPresent(String.self, forKey: .formatVersion))
        let syncDatabaseId = decoder.userInfo[BeamObject.beamObjectId] as? UUID ?? UUID.null
        id = (try container.decodeIfPresent(UUID.self, forKey: .id)) ?? syncDatabaseId
        databaseId = try container.decode(UUID.self, forKey: .databaseId)
        source = (try container.decodeIfPresent(String.self, forKey: .source)) ?? "decoder"
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        data = try container.decode(String.self, forKey: .data).asData
        if container.contains(.version) {
            version = (try? container.decode(BeamVersion.self, forKey: .version)) ?? BeamVersion()
        }

        journalDate = 0

        let documentTypeAsString = try container.decode(String.self, forKey: .documentType)
        switch documentTypeAsString {
        case "journal":
            documentType = .journal
            if let stringDate = try container.decodeIfPresent(String.self, forKey: .journalDate) {
                journalDate = JournalDateConverter.toInt(from: stringDate)
            } else {
                journalDate = try container.decode(Int64.self, forKey: .journalDate)
            }
        
        case "tabGroup":
            guard let tabGroupId = try? container.decodeIfPresent(UUID.self, forKey: .tabGroupId) else {
                fallthrough
            }
            self.tabGroupId = tabGroupId
            documentType = .tabGroup
        case "note":
            documentType = .note
        default:
            documentType = .note
            Logger.shared.logError("Can't decode \(documentTypeAsString)", category: .document)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let syncCoding = encoder.userInfo[BeamObject.beamObjectCoding] as? Bool ?? false
        if !syncCoding {
            try container.encode(id, forKey: .id)
            try container.encode(source, forKey: .source)
        }
        if let dbId = database?.id ?? databaseId {
            try container.encode(dbId, forKey: .databaseId)
        }
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if deletedAt != nil {
            try container.encode(deletedAt, forKey: .deletedAt)
        }

        try container.encode(data.asString, forKey: .data)
        switch documentType {
        case .journal:
            try container.encode("journal", forKey: .documentType)
            try container.encode(JournalDateConverter.toString(from: journalDate), forKey: .journalDate)
        case .tabGroup:
            try container.encode("tabGroup", forKey: .documentType)
            if let tabGroupId = tabGroupId {
                try container.encode(tabGroupId, forKey: .tabGroupId)
            }
        case .note:
            try container.encode("note", forKey: .documentType)
        }

        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(version, forKey: .version)

        try container.encode(Self.formatVersion, forKey: .formatVersion)
    }
}

public extension BeamDocument {
    init(document: BeamDocument) {
        self.id = document.id
        self.source = document.source
        self.database = document.database
        self.databaseId = document.databaseId
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
        self.deletedAt = document.deletedAt
        self.title = document.title
        self.documentType = document.documentType
        self.data = document.data
        self.version = document.version
        self.isPublic = document.isPublic
        self.journalDate = document.journalDate
        self.tabGroupId = document.tabGroupId
    }
}

extension BeamDocument: Equatable {
    static public func == (lhs: BeamDocument, rhs: BeamDocument) -> Bool {

        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        lhs.id == rhs.id &&
        lhs.database === rhs.database &&
        lhs.title == rhs.title &&
        lhs.data == rhs.data &&
        lhs.documentType == rhs.documentType &&
        lhs.isPublic == rhs.isPublic &&
        lhs.createdAt.intValue == rhs.createdAt.intValue &&
        lhs.updatedAt.intValue == rhs.updatedAt.intValue &&
        lhs.deletedAt?.intValue == rhs.deletedAt?.intValue &&
        lhs.journalDate == rhs.journalDate &&
        lhs.tabGroupId == rhs.tabGroupId
    }
}

extension BeamDocument: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(database?.id ?? databaseId ?? UUID.null)
        hasher.combine(id)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(deletedAt)
        hasher.combine(title)
        hasher.combine(documentType)
        hasher.combine(data)
        hasher.combine(version)
        hasher.combine(isPublic)
        hasher.combine(journalDate)
        hasher.combine(tabGroupId)
    }
}

extension BeamVersion: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(self)
        } catch {
            Logger.shared.logError("Error while encoding BeamVersion: \(error)", category: .document)
            fatalError("Error while encoding BeamVersion: \(error)")
        }

        guard let value = DatabaseValue(value: data) else {
            fatalError("Error while making BeamVersion a DatabaseValue: \(self) - \(data)")
        }
        return value
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let data = Data.fromDatabaseValue(dbValue) else {
            return nil
        }

        let decoder = JSONDecoder()
        if let version = try? decoder.decode(Self.self, from: data) {
            return version
        }
        return nil
    }

}

extension BeamDocument: TableRecord {
    public enum Columns: String, ColumnExpression {
        case id, source, title, createdAt, updatedAt, data, documentType, version, isPublic, journalDate, tabGroupId
    }
}

extension DocumentType: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { DatabaseValue(value: self.rawValue)! }

    /// Returns a value initialized from `dbValue`, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        switch dbValue.storage {
        case .int64(let value):
            return DocumentType(rawValue: Int16(value))

        default:
            return nil
        }
    }
}

extension BeamDocument: FetchableRecord {
    public init(row: Row) {
        id = row[Columns.id]
        source = row[Columns.source]
        database = nil
        title = row[Columns.title]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        data = row[Columns.data]
        documentType = row[Columns.documentType]
        let versionValue = row[Columns.version]
        if let versionData = versionValue as? Data {
            let decoder = JSONDecoder()
            if let v = try? decoder.decode(BeamVersion.self, from: versionData) {
                version = v
            } else {
                version = BeamVersion()
            }
        } else if let v = versionValue as? Int {
            version = BeamVersion(localVersion: v)
        }
        isPublic = row[Columns.isPublic]
        journalDate = row[Columns.journalDate]
        tabGroupId = row[Columns.tabGroupId]
    }
}

extension BeamDocument: MutablePersistableRecord {
    /// The values persisted in the database
    public func encode(to container: inout PersistenceContainer) {
        // We can't associate the id with the one in a virtual table, it creates errors in SQLite
        container[Columns.id] = id
        container[Columns.source] = source
        container[Columns.title] = title
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.data] = data
        container[Columns.documentType] = documentType
        container[Columns.version] = version
        container[Columns.isPublic] = isPublic
        container[Columns.journalDate] = journalDate
        container[Columns.tabGroupId] = tabGroupId
    }
}

public extension BeamDocument {
    func textDescription() throws -> String {
        let beamNote = try BeamNote.instanciateNote(self,
                                                    keepInMemory: false,
                                                    decodeChildren: true)

        return beamNote.textDescription()
    }
}

public extension BeamDocument {
    private(set) static var formatVersionMain = "0.1.0"
    static var formatVersionVariant = ""
    static var formatVersion: String { [formatVersionMain, formatVersionVariant].joined(separator: " - ") }
    static private func checkFormatVersion(_ version: String?) throws {
        // Do nothing for now
    }
}


public extension DocumentType {
    init(from beamNoteType: BeamNoteType) {
        switch beamNoteType {
        case .journal: self = .journal
        case .tabGroup: self = .tabGroup
        case .note: self = .note
        }
    }
}
