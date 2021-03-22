import Foundation

extension String {
    var uuid: UUID? {
        return UUID(uuidString: self)
    }
}
