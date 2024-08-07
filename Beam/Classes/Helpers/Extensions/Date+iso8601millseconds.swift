// From https://stackoverflow.com/questions/28016578/how-can-i-parse-create-a-date-time-stamp-formatted-with-fractional-seconds-utc

import Foundation
import BeamCore
import JJLISO8601DateFormatter

// JJLISO8601DateFormatter is a 10x+ faster drop-in replacement for NSISO8601DateFormatter
private var _iso8601withFractionalSeconds: JJLISO8601DateFormatter = {
    let formatter = JJLISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options) {
        self.init()
        self.formatOptions = formatOptions
    }
}

extension Formatter {
    static let iso8601withFractionalSeconds = _iso8601withFractionalSeconds
    static let iso8601 = ISO8601DateFormatter()
}

extension Date {
    var iso8601withFractionalSeconds: String { return Formatter.iso8601withFractionalSeconds.string(from: self) }

    var isoCalStartOfDay: Date {
        let cal = Calendar(identifier: .iso8601)
        return cal.startOfDay(for: self)
    }

    var isoCalEndOfDay: Date {
        let cal = Calendar(identifier: .iso8601)

        var components = DateComponents()
        components.day = 1
        components.second = -1
        return cal.date(byAdding: components, to: isoCalStartOfDay)!
    }

    var formatHourMin: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

extension String {
    var iso8601withFractionalSeconds: Date? { return Formatter.iso8601withFractionalSeconds.date(from: self) }
}

extension JSONEncoder.DateEncodingStrategy {
    static let iso8601withFractionalSeconds = custom {
        var container = $1.singleValueContainer()
        try container.encode(Formatter.iso8601withFractionalSeconds.string(from: $0))
    }
}

extension BeamJSONDecoder.DateDecodingStrategy {
    static let iso8601withFractionalSeconds = custom {
        let container = try $0.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = (Formatter.iso8601withFractionalSeconds.date(from: string) ?? Formatter.iso8601.date(from: string)) else {
            throw DecodingError.dataCorruptedError(in: container,
                  debugDescription: "Invalid date: " + string)
        }
        return date
    }
}
