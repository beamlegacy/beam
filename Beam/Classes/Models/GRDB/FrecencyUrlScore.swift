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
        frecencySortScore = row[Columns.frecencySortScore] ??  -Float.greatestFiniteMagnitude
        frecencyKey = row[Columns.frecencyKey]
    }
}

extension FrecencyUrlRecord: PersistableRecord {
    /// The values persisted in the database
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.urlId] = urlId
        container[Columns.lastAccessAt] = lastAccessAt
        container[Columns.frecencyScore] = frecencyScore
        container[Columns.frecencySortScore] = frecencySortScore
        container[Columns.frecencyKey] = frecencyKey
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
        let record = FrecencyUrlRecord(urlId: score.id,
                                       lastAccessAt: score.lastTimestamp,
                                       frecencyScore: score.lastScore,
                                       frecencySortScore: score.sortValue,
                                       frecencyKey: paramKey)
        try GRDBDatabase.shared.saveFrecencyUrl(record)
    }
    public func save(scores: [FrecencyScore], paramKey: FrecencyParamKey) throws {
        let records = scores.map { score in
            FrecencyUrlRecord(
                urlId: score.id,
                lastAccessAt: score.lastTimestamp,
                frecencyScore: score.lastScore,
                frecencySortScore: score.sortValue,
                frecencyKey: paramKey
            )
        }
        try GRDBDatabase.shared.save(urlFrecencies: records)
    }
}
