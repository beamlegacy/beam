import Foundation
import CryptoKit
import BeamCore

enum EncryptionManagerError: Error {
    case authenticationFailure
    case stringEncodingError
    case keyError
}
extension EncryptionManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authenticationFailure:
            return loc("Couldn't decrypt data, encrypted with a different private key?")
        case .stringEncodingError:
            return loc("Couldn't change String to Data.")
        case .keyError:
            return loc("Key couldn't be read")
        }
    }
}

// https://medium.com/swlh/common-cryptographic-operations-in-swift-with-cryptokit-b30a4becc895
class EncryptionManager {
    static let shared = EncryptionManager()

    enum Algorithm: String, CaseIterable {
        case ChaChaPoly
        case AES_GCM
    }

    func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    func clearPrivateKey() {
        Logger.shared.logWarning("Private key has been cleared", category: .encryption)
        Persistence.Encryption.privateKey = nil
    }

    func replacePrivateKey(_ base64EncodedString: String) throws {
        guard let key = SymmetricKey(base64EncodedString: base64EncodedString) else {
            throw EncryptionManagerError.keyError
        }

        Logger.shared.logWarning("Private key has been replaced", category: .encryption)
        Persistence.Encryption.privateKey = key.asString()
    }

    func resetPrivateKey() {
        Logger.shared.logWarning("Private key has been reset", category: .encryption)
        Persistence.Encryption.privateKey = nil
    }

    func privateKey() -> SymmetricKey {
        guard let dataKey = Persistence.Encryption.privateKey,
              let result = SymmetricKey(base64EncodedString: dataKey) else {

                  Logger.shared.logWarning("Private key doesn't exist or has a wrong format: \(Persistence.Encryption.privateKey ?? "-"), creating new one",
                                           category: .encryption)

                  let key = generateKey()
                  Persistence.Encryption.privateKey = key.asString()
                  return key
              }

        return result
    }

    func encryptString(_ string: String, using: Algorithm = .AES_GCM) throws -> String? {
        switch using {
        case .ChaChaPoly:
            return try ChaChaPoly
                .seal(string.asData, using: privateKey())
                .combined
                .base64EncodedString()
        case .AES_GCM:
            return try AES.GCM
                .seal(string.asData, using: privateKey())
                .combined?
                .base64EncodedString()
        }
    }

    func decryptString(_ encryptedString: String, _ key: SymmetricKey? = nil, using: Algorithm = .AES_GCM) throws -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            Logger.shared.logError("Couldn't change String to Data", category: .encryption)
            throw EncryptionManagerError.stringEncodingError
        }

        do {
            switch using {
            case .ChaChaPoly:
                let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
                let decryptedData = try ChaChaPoly.open(sealedBox, using: key ?? privateKey())
                return decryptedData.asString
            case .AES_GCM:
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: key ?? privateKey())
                return decryptedData.asString
            }
        } catch CryptoKit.CryptoKitError.authenticationFailure {
            throw EncryptionManagerError.authenticationFailure
        }
    }

    func encryptData(_ data: Data, using: Algorithm = .AES_GCM) throws -> Data? {
        switch using {
        case .ChaChaPoly:
            return try ChaChaPoly.seal(data, using: privateKey()).combined
        case .AES_GCM:
            return try AES.GCM
                .seal(data, using: privateKey())
                .combined
        }
    }

    func decryptData(_ encryptedData: Data, _ key: SymmetricKey? = nil, using: Algorithm = .AES_GCM) throws -> Data? {
        switch using {
        case .ChaChaPoly:
            let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
            let decryptedData = try ChaChaPoly.open(sealedBox, using: key ?? privateKey())
            return decryptedData
        case .AES_GCM:
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key ?? privateKey())
            return decryptedData
        }
    }
}
