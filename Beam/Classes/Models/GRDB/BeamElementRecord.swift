import GRDB

// Declare a record struct, data, how it is stored within the DB.
// Refer to GRDB Database for read/write operations.

// Previous version:
//struct BeamElementRecord {
//    var id: Int64?
//    var title: String
//    var uid: String
//    var text: String
//}

struct BeamElementRecord {
    var id: Int64?
    var title: String
    var text: String
    var uid: String
    var noteId: String // Added noteId
    var databaseId: String
    var linkRanges: LinkRanges

    static let frecency = hasOne(FrecencyNoteRecord.self, key: "frecency", using: FrecencyNoteRecord.BeamElementForeignKey)

    struct LinkRanges: DatabaseValueConvertible {
        var databaseValue: DatabaseValue {
            var data = Data()
            data.reserveCapacity(MemoryLayout<Int64>.stride*2*ranges.count)

            for range in ranges {
                var lowerBound = Int64(range.lowerBound)
                var upperBound = Int64(range.upperBound)
                withUnsafeBytes(of: &lowerBound) { buffer in
                    data.append(contentsOf: buffer)
                }
                withUnsafeBytes(of: &upperBound) { buffer in
                    data.append(contentsOf: buffer)
                }
            }

            guard let value = DatabaseValue(value: data) else {
                fatalError("Error while making bidilink ranges database value")
            }

            return value
        }

        static func fromDatabaseValue(_ dbValue: DatabaseValue) -> LinkRanges? {
            guard let data = Data.fromDatabaseValue(dbValue) else {
                return nil
            }

            let stride = MemoryLayout<Int64>.stride
            let quotientAndRemainder = data.count.quotientAndRemainder(dividingBy: stride*2)

            guard quotientAndRemainder.remainder == 0 else {
                return nil
            }

            let ranges = (0..<quotientAndRemainder.quotient).map { index -> Range<Int> in
                var lowerBound: Int64 = 0
                var upperBound: Int64 = 0
                let index = index*stride*2
                withUnsafeMutableBytes(of: &lowerBound) { buffer in
                    _ = data.copyBytes(to: buffer, from: index..<index+stride)
                }
                withUnsafeMutableBytes(of: &upperBound) { buffer in
                    _ = data.copyBytes(to: buffer, from: index+stride..<index+stride*2)
                }
                return Int(lowerBound)..<Int(upperBound)
            }

            return LinkRanges(ranges)
        }

        let ranges: [Range<Int>]

        init(_ ranges: [Range<Int>]) {
            self.ranges = ranges
        }
    }
}

// SQL generation
extension BeamElementRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, text, uid, noteId, databaseId, linkRanges
    }
}

// Fetching methods
extension BeamElementRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        text = row[Columns.text]
        uid = row[Columns.uid]
        noteId = row[Columns.noteId]
        databaseId = row[Columns.databaseId]
        linkRanges = row[Columns.linkRanges]
    }
}

// Persistence methods
extension BeamElementRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        // We can't associate the id with the one in a virtual table, it creates errors in SQLite
        container[Columns.title] = title
        container[Columns.text] = text
        container[Columns.uid] = uid
        container[Columns.noteId] = noteId
        container[Columns.databaseId] = databaseId
        container[Columns.linkRanges] = linkRanges
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

struct BeamNoteIndexingRecord {
    var id: Int64?
    var noteId: String
    var indexedAt: Date
}

// SQL generation
extension BeamNoteIndexingRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, noteId, indexedAt
    }
}

// Fetching methods
extension BeamNoteIndexingRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        noteId = row[Columns.noteId]
        indexedAt = row[Columns.indexedAt]
    }
}

// Persistence methods
extension BeamNoteIndexingRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        // We can't associate the id with the one in a virtual table, it creates errors in SQLite
        container[Columns.noteId] = noteId
        container[Columns.indexedAt] = indexedAt
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
