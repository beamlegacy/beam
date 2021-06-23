import Foundation

public extension String {
    var uuid: UUID? {
        return UUID(uuidString: self)
    }
}

public extension UUID {
    static let nullString = "00000000-0000-0000-0000-000000000000"
    static let null = UUID(uuidString: Self.nullString)!
}
