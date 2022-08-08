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

    public static let databaseTableName = "frecencyUrlRecord"
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
    private var overridenManager: UrlHistoryManager?
    private var manager: UrlHistoryManager {
        overridenManager ?? BeamData.shared.urlHistoryManager!
    }

    init(overridenManager: UrlHistoryManager? = nil) {
        self.overridenManager = overridenManager
    }

    public func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
        do {
            if let record = try manager.fetchOneFrecency(fromUrl: id)[paramKey] {
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
    public func fetchMany(ids: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyScore] {
        let keyValues = manager.getFrecencies(urlIds: ids, paramKey: paramKey)
            .map { (id, record) in
                (id, FrecencyScore(id: record.urlId,
                                   lastTimestamp: record.lastAccessAt,
                                   lastScore: record.frecencyScore,
                                   sortValue: record.frecencySortScore))
            }
        return Dictionary(uniqueKeysWithValues: keyValues)
    }

    public func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
        let record = FrecencyUrlRecord(urlId: score.id,
                                       lastAccessAt: score.lastTimestamp,
                                       frecencyScore: score.lastScore,
                                       frecencySortScore: score.sortValue,
                                       frecencyKey: paramKey)
        try manager.saveFrecencyUrl(record)
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
        try manager.save(urlFrecencies: records)
    }
}

class LinkStoreFrecencyUrlStorage: FrecencyStorage {
    let linkDB: BeamLinkDB

    init(overridenManager: UrlHistoryManager? = nil) {
        linkDB = BeamLinkDB(overridenManager: overridenManager)
    }
    func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
        guard paramKey == .webVisit30d0,
              let link = linkDB.linkFor(id: id),
              let lastAccessAt = link.frecencyVisitLastAccessAt,
              let score = link.frecencyVisitScore,
              let sortScore = link.frecencyVisitSortScore else { return nil }
        return FrecencyScore(id: id, lastTimestamp: lastAccessAt, lastScore: score, sortValue: sortScore)
    }
    func fetchMany(ids: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyScore] {
        guard paramKey == .webVisit30d0 else { return [UUID: FrecencyScore]() }
        do {
            let links = try linkDB.fetchWithIds(ids)
            let scores = links.compactMap { link -> (UUID, FrecencyScore)? in
                guard let lastAccessAt = link.frecencyVisitLastAccessAt,
                    let score = link.frecencyVisitScore,
                    let sortScore = link.frecencyVisitSortScore else { return nil }
                return (link.id, FrecencyScore(id: link.id, lastTimestamp: lastAccessAt, lastScore: score, sortValue: sortScore))
            }
            return Dictionary(uniqueKeysWithValues: scores)
        } catch {
            Logger.shared.logError("Couldn't fetch url frecencies: \(error)", category: .database)
            return [UUID: FrecencyScore]()
        }
    }

    func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
        guard paramKey == .webVisit30d0 else { return }
        linkDB.updateFrecency(id: score.id, lastAccessAt: score.lastTimestamp, score: score.lastScore, sortScore: score.sortValue)
    }

    func save(scores: [FrecencyScore], paramKey: FrecencyParamKey) throws {
        guard paramKey == .webVisit30d0 else { return }
        linkDB.updateFrecencies(scores: scores)
    }
}
