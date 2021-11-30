import Foundation

public class BeamDate {
    static var currentDate: Date?

    public static var now: Date {
        // swiftlint:disable:next date_init
        currentDate ?? Date()
    }

    public static func travel(_ duration: TimeInterval) {
        // Force storing the value of time
        currentDate = currentDate ?? now

        currentDate?.addTimeInterval(duration)
    }

    public static func freeze(_ dateString: String? = nil) {
        guard let dateString = dateString else {
            currentDate = now
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        currentDate = dateFormatter.date(from: dateString)
    }

    public static func reset() {
        currentDate = nil
    }

    public static func journalNoteTitle(for date: Date = now, with style: DateFormatter.Style = .long) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = style
        fmt.timeStyle = .none
        fmt.doesRelativeDateFormatting = false
        return fmt.string(from: date)
    }
}
