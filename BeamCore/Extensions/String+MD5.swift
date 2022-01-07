import Foundation
import CryptoKit

public extension String {
    enum MD5Error: Error {
        case noData
    }

    func MD5() throws -> String {
        guard let stringData = data(using: .utf8) else {
            throw MD5Error.noData
        }
        let digest = Insecure.MD5.hash(data: stringData)

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined().lowercased()
    }
}

public extension Data {
    var MD5: String {
        let digest = Insecure.MD5.hash(data: self)

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined().lowercased()
    }

    var md5Base64: String {
        Data(Insecure.MD5.hash(data: self)).base64EncodedString()
    }
}
