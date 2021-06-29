import BeamCore
import GRDB

struct FrecencyUrlRecord {
    /// URL id from LinkStore
    var urlId: UInt64
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

class GRDBFrecencyStorage: FrecencyStorage {
    func fetchOne(urlId: UInt64, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
        do {
            if let record = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: urlId)[paramKey] {
                return FrecencyScore(urlId: record.urlId,
                                     lastTimestamp: record.lastAccessAt,
                                     lastScore: record.frecencyScore,
                                     sortValue: record.frecencySortScore)
            }
        } catch {
            Logger.shared.logError("unable to fetch frecency for urlId \(urlId): \(error)", category: .database)
        }

        return nil
    }

    func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
        var record = FrecencyUrlRecord(urlId: score.urlId,
                                       lastAccessAt: score.lastTimestamp,
                                       frecencyScore: score.lastScore,
                                       frecencySortScore: score.sortValue,
                                       frecencyKey: paramKey)
        try GRDBDatabase.shared.saveFrecencyUrl(&record)
    }
}
