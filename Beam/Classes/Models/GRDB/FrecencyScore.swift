import BeamCore
import GRDB

public struct FrecencyUrlRecord {
    /// URL id from LinkStore
    var urlId: UUID
    var lastAccessAt: Date
    /// Frecency internal score. Not suited for querying.
    var frecencyScore: Float
    /// Frecency score to sort URLs in a search query.
    var frecencySortScore: Float
    var frecencyKey: FrecencyParamKey
}

// SQL generation
extension FrecencyUrlRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case urlId, lastAccessAt, frecencyScore, frecencySortScore, frecencyKey
    }

    // FIXME: make relation with LinkStore
    // static let history = belongsTo(HistoryUrlRecord.self, using: ForeignKey([HistoryUrlRecord.Columns.urlId]))
}

extension FrecencyParamKey: DatabaseValueConvertible {
}

// Fetching methods
extension FrecencyUrlRecord: FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        urlId = row[Columns.urlId]
        lastAccessAt = row[Columns.lastAccessAt]
        frecencyScore = row[Columns.frecencyScore]
        frecencySortScore = row[Columns.frecencySortScore]
        frecencyKey = row[Columns.frecencyKey]
    }
}

extension FrecencyUrlRecord: MutablePersistableRecord {
    /// The values persisted in the database
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.urlId] = urlId
        container[Columns.lastAccessAt] = lastAccessAt
        container[Columns.frecencyScore] = frecencyScore
        container[Columns.frecencySortScore] = frecencySortScore
        container[Columns.frecencyKey] = frecencyKey
    }
}

public struct FrecencyNoteRecord: Codable {
    public static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.string
    var noteId: UUID
    var lastAccessAt: Date
    /// Frecency internal score. Not suited for querying.
    var frecencyScore: Float
    /// Frecency score to sort notes in a search query.
    var frecencySortScore: Float
    var frecencyKey: FrecencyParamKey

    static let BeamElementForeignKey = ForeignKey([FrecencyNoteRecord.Columns.noteId], to: [BeamElementRecord.Columns.noteId])

    enum CodingKeys: String, CodingKey {
        case noteId
        case lastAccessAt
        case frecencyScore
        case frecencySortScore
        case frecencyKey
    }
}

extension FrecencyNoteRecord: FetchableRecord {}

extension FrecencyNoteRecord: PersistableRecord {}

extension FrecencyNoteRecord: TableRecord {
    enum Columns {
            static let noteId = Column(CodingKeys.noteId)
            static let lastAccessAt = Column(CodingKeys.lastAccessAt)
            static let frecencyScore = Column(CodingKeys.frecencyScore)
            static let frecencySortScore = Column(CodingKeys.frecencySortScore)
            static let frecencyKey = Column(CodingKeys.frecencyKey)
        }
}

public class GRDBUrlFrecencyStorage: FrecencyStorage {
    public func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
        do {
            if let record = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: id)[paramKey] {
                return FrecencyScore(id: record.urlId,
                                     lastTimestamp: record.lastAccessAt,
                                     lastScore: record.frecencyScore,
                                     sortValue: record.frecencySortScore)
            }
        } catch {
            Logger.shared.logError("unable to fetch frecency for urlId \(id): \(error)", category: .database)
        }

        return nil
    }

    public func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
        var record = FrecencyUrlRecord(urlId: score.id,
                                       lastAccessAt: score.lastTimestamp,
                                       frecencyScore: score.lastScore,
                                       frecencySortScore: score.sortValue,
                                       frecencyKey: paramKey)
        try GRDBDatabase.shared.saveFrecencyUrl(&record)
    }
}

public class GRDBNoteFrecencyStorage: FrecencyStorage {
    public func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
        do {
            if let record = try GRDBDatabase.shared.fetchOneFrecencyNote(noteId: id, paramKey: paramKey) {
                return FrecencyScore(id: record.noteId,
                                     lastTimestamp: record.lastAccessAt,
                                     lastScore: record.frecencyScore,
                                     sortValue: record.frecencySortScore)
            }
        } catch {
            Logger.shared.logError("unable to fetch frecency for urlId \(id): \(error)", category: .database)
        }
        return nil
    }

    public func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
        let record = FrecencyNoteRecord(noteId: score.id,
                                       lastAccessAt: score.lastTimestamp,
                                       frecencyScore: score.lastScore,
                                       frecencySortScore: score.sortValue,
                                       frecencyKey: paramKey)
        try GRDBDatabase.shared.saveFrecencyNote(record)
    }
}
