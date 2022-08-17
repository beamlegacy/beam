import Foundation
import Combine

enum NoteType: String, Codable {
    case journal
    case note
}

public enum BeamNoteType: Codable, Equatable {
    case journal(String) // The date is stored as an ISO 8601 string
    case note
    case tabGroup(UUID)

    public var isJournal: Bool {
        switch self {
        case .journal:
            return true
        default:
            return false
        }
    }

    public var isTabGroup: Bool {
        switch self {
        case .tabGroup:
            return true
        default:
            return false
        }
    }

    public var journalDate: Date? {
        switch self {
        case .journal(let dateString):
            guard !dateString.isEmpty else { return nil }
            return Self.dateFormater.date(from: dateString)
        default:
            return nil
        }
    }

    public var journalDateString: String? {
        switch self {
        case .journal(let dateString):
            return dateString
        default:
            return nil
        }
    }

    public var tabGroupId: UUID? {
        switch self {
        case .tabGroup(let id):
            return id
        default:
            return nil
        }
    }

    public static var dateFormater: ISO8601DateFormatter = {
        let formater = ISO8601DateFormatter()
        formater.timeZone = .current
        formater.formatOptions = .withFullDate
        return formater
    }()

    public var isFutureJournal: Bool {
        switch self {
        case .journal(let dateString):
            guard let date = Self.dateFormater.date(from: dateString) else { return false }
            let calendar = Calendar(identifier: .iso8601)
            // First check is the date is today, which means it's not in the future
            guard !calendar.isDateInToday(date) else { return false }
            // Then compare with now
            return date > BeamDate.now

        default:
            return false
        }
    }

    public static func previousJournal() -> BeamNoteType {
        let calendar = Calendar(identifier: .iso8601)
        let previousJournalDate = calendar.date(byAdding: .day, value: -1, to: BeamDate.now) ?? BeamDate.now
        return .journal(titleForDate(previousJournalDate))
    }

    public static func nextJournal() -> BeamNoteType {
        let calendar = Calendar(identifier: .iso8601)
        let nextJournalDate = calendar.date(byAdding: .day, value: 1, to: BeamDate.now) ?? BeamDate.now
        return .journal(titleForDate(nextJournalDate))
    }

    public static var todaysJournal: BeamNoteType {
        return Self.journalForDate(BeamDate.now)
    }

    public static func titleForDate(_ date: Date) -> String {
        return dateFormater.string(from: date)
    }

    public static func iso8601ForDate(_ date: Date) -> String {
        return dateFormater.string(from: date)
    }

    public static func journalForDate(_ date: Date) -> BeamNoteType {
        return .journal(titleForDate(date))
    }

    public static func dateFrom(journalDateString: String) -> Date? {
        guard !journalDateString.isEmpty else { return nil }
        return Self.dateFormater.date(from: journalDateString)
    }

    public static func dateFrom(journalDateInt: Int64) -> Date? {
        guard journalDateInt != 0 else { return nil }

        return Self.dateFormater.date(from: JournalDateConverter.toString(from: journalDateInt))
    }

    public static func intFrom(journalDate: Date) -> Int64 {
        JournalDateConverter.toInt(from: Self.iso8601ForDate(journalDate))
    }

    static func fromOldType(_ oldType: NoteType, title: String, fallbackDate: Date) -> BeamNoteType {
        switch oldType {
        case .journal:
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.doesRelativeDateFormatting = false
            fmt.timeStyle = .none
            let date = fmt.date(from: title) ?? fallbackDate
            return journalForDate(date)
        case .note:
            return .note
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case date
        case tabGroupId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .type)
        switch value {
        case "journal":
            var date = (try? container.decode(String.self, forKey: .date)) ?? ""
            // make sure the stored date is valid:
            if Self.dateFormater.date(from: date) == nil {
                date = ""
            }
            self = .journal(date)
        case "note":
            self = .note
        case "tabGroup":
            guard let id = (try? container.decode(UUID.self, forKey: .tabGroupId)) else {
                fallthrough
            }
            self = .tabGroup(id)
        default:
            Logger.shared.logError("Invalid NoteType '\(value)'", category: .document)
            self = .note
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .journal(let date):
            try container.encode("journal", forKey: .type)
            try container.encode(date, forKey: .date)
        case .tabGroup(let groupId):
            try container.encode("tabGroup", forKey: .type)
            try container.encode(groupId, forKey: .tabGroupId)
        case .note:
            try container.encode("note", forKey: .type)
        }
    }
}
