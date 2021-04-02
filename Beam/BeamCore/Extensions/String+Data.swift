import Foundation

public extension String {
    var asData: Data {
        return Data(utf8)
    }
}
