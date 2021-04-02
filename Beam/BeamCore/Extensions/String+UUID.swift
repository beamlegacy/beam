import Foundation

public extension String {
    var uuid: UUID? {
        return UUID(uuidString: self)
    }
}
