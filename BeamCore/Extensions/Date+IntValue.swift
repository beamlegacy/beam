import Foundation

extension Date {
    public var intValue: Int {
        Int(timeIntervalSince1970)
    }
}
