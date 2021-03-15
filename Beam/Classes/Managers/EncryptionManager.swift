import Foundation
import CryptoKit

// https://medium.com/swlh/common-cryptographic-operations-in-swift-with-cryptokit-b30a4becc895
class EncryptionManager {
    static let shared = EncryptionManager()

    let name = "ChaChaPoly"

    func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    func clearPrivateKey() {
        Persistence.Encryption.privateKey = nil
    }

    func privateKey() -> SymmetricKey {
        guard let dataKey = Persistence.Encryption.privateKey else {
            let key = generateKey()
            Persistence.Encryption.privateKey = key.asData()
            return key
        }

        return SymmetricKey(data: dataKey)
    }

    func encryptString(_ string: String) throws -> String? {
        try ChaChaPoly.seal(string.asData, using: privateKey()).combined.base64EncodedString()
    }

    func decryptString(_ encryptedString: String, _ key: SymmetricKey? = nil) throws -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            Logger.shared.logError("Couldn't change String to Data", category: .encryption)
            return nil
        }

        let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
        let decryptedData = try ChaChaPoly.open(sealedBox, using: key ?? privateKey())

        return decryptedData.asString
    }

    func encryptData(_ data: Data) throws -> Data? {
        try ChaChaPoly.seal(data, using: privateKey()).combined
    }

    func decryptData(_ encryptedData: Data, _ key: SymmetricKey? = nil) throws -> Data? {
        let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
        let decryptedData = try ChaChaPoly.open(sealedBox, using: key ?? privateKey())

        return decryptedData
    }
}
