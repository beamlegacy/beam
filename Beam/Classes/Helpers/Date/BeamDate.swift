import Foundation

class BeamDate {
    static var currentDate: Date?

    static var now: Date {
        currentDate ?? Date()
    }

    static func travel(_ duration: TimeInterval) {
        // Force storing the value of time
        currentDate = currentDate ?? now

        currentDate?.addTimeInterval(duration)
    }

    static func freeze(_ dateString: String? = nil) {
        guard let dateString = dateString else {
            currentDate = now
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        currentDate = dateFormatter.date(from: dateString)
    }

    static func reset() {
        currentDate = nil
    }

    static func str(for date: Date, with style: DateFormatter.Style) -> String {
        let fmt = DateFormatter()
        if style == .short {
            fmt.dateFormat = "MMM d, yy"
        } else {
            fmt.dateStyle = style
            fmt.timeStyle = .none
            fmt.doesRelativeDateFormatting = false
        }
        return fmt.string(from: date)
    }
}
