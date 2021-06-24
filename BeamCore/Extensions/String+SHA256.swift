import Foundation
import CryptoKit

public extension String {
    enum SHA256Error: Error {
        case noData
    }

    func SHA256() throws -> String {
        guard let stringData = data(using: .utf8) else {
            throw SHA256Error.noData
        }
        let digest = CryptoKit.SHA256.hash(data: stringData)

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined().lowercased()
    }
}

public extension Data {
    var SHA256: String {
        let digest = CryptoKit.SHA256.hash(data: self)

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined().lowercased()
    }
}
