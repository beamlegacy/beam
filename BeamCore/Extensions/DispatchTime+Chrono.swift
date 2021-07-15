import Foundation

public extension DispatchTime {
    enum TimeUnit: String {
        case ns
        case µs
        case ms
        case s
    }
}

func computeTimeInterval(startTimeNanoseconds: UInt64, endTimeNanoseconds: UInt64) -> (UInt64, DispatchTime.TimeUnit) {
    var timeInterval = endTimeNanoseconds - startTimeNanoseconds
    var timeUnit = DispatchTime.TimeUnit.ns
    var i = 3
    while i > 0 && timeInterval >= 1000 {
        switch timeUnit {
        case .ns:
            timeUnit = .µs
        case .µs:
            timeUnit = .ms
        case .ms:
            timeUnit = .s
        case .s:
            continue
        }

        timeInterval /= 1_000 // Technically could overflow for long running tests
        i -= 1
    }
    return (timeInterval, timeUnit)
}

/// Interrupt the current chrono and computes the elapsed time.
/// Useful to display a chrono in a user readable way.
/// - Returns: elapsed time and time unit
public extension DispatchTime {
   func endChrono(endChrono: DispatchTime = DispatchTime.now()) -> (UInt64, TimeUnit) {
        computeTimeInterval(startTimeNanoseconds: self.uptimeNanoseconds, endTimeNanoseconds: endChrono.uptimeNanoseconds)
   }
}
