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

    static func freeze() {
        currentDate = now
    }

    static func reset() {
        currentDate = nil
    }
}
