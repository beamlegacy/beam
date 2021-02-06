import Foundation

extension Data {
    var asString: String? {
        String(data: self, encoding: .utf8)
    }
}
