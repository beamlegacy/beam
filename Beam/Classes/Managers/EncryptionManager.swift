import Foundation
import CryptoKit
import BeamCore
import KeychainAccess

enum EncryptionManagerError: Error {
    case authenticationFailure
    case stringEncodingError
    case stringDecodingError
    case keyError
    case internalEncryptionError
}
extension EncryptionManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authenticationFailure:
            return loc("Couldn't decrypt data, encrypted with a different private key?")
        case .stringEncodingError:
            return loc("Couldn't change String to Data.")
        case .stringDecodingError:
            return loc("Couldn't decode UTF-8")
        case .keyError:
            return loc("Key couldn't be read")
        case .internalEncryptionError:
            return loc("Internal encryption error")
        }
    }
}

// https://medium.com/swlh/common-cryptographic-operations-in-swift-with-cryptokit-b30a4becc895
class EncryptionManager {
    static let shared = EncryptionManager()
    private let lock = RWLock()

    enum Algorithm: String, CaseIterable {
        case ChaChaPoly
        case AES_GCM
    }

    func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    // MARK: - Local Private Key
    private var cachedLocalPrivateKey: String? // avoid hitting the keychain for each request

    func loadLocalPrivateKey() throws -> String? {
        if cachedLocalPrivateKey != nil {
            return cachedLocalPrivateKey
        }
        let keychain = Keychain(service: Configuration.bundleIdentifier).synchronizable(false)
        cachedLocalPrivateKey = try keychain.getString(Persistence.Encryption.localPrivateKeyName)
        return cachedLocalPrivateKey
    }

    func storeLocalPrivateKey(_ privateKey: String) throws {
        let keychain = Keychain(service: Configuration.bundleIdentifier).synchronizable(false)
        try keychain.set(privateKey, key: Persistence.Encryption.localPrivateKeyName)
        cachedLocalPrivateKey = privateKey
    }

    @discardableResult
    func localPrivateKey(allowCreating: Bool = false) throws -> SymmetricKey {
        try lock.write {
            if let localDataKey = try self.loadLocalPrivateKey(),
               let localPrivateKey = SymmetricKey(base64EncodedString: localDataKey) {
                return localPrivateKey
            }
            guard allowCreating else {
                Logger.shared.logError("Local Private key doesn't exist or has a wrong format, password manager will be disabled", category: .encryption)
                throw EncryptionManagerError.keyError
            }
            Logger.shared.logInfo("Local Private key doesn't exist or has a wrong format, creating new one", category: .encryption)
            let key = self.generateKey()
            try self.storeLocalPrivateKey(key.asString())
            return key
        }
    }

    // MARK: - Encrypt / Decrypt
    func encryptString(_ string: String, _ key: SymmetricKey, using: Algorithm = .AES_GCM) throws -> String? {
        switch using {
        case .ChaChaPoly:
            return try ChaChaPoly
                .seal(string.asData, using: key)
                .combined
                .base64EncodedString()
        case .AES_GCM:
            return try AES.GCM
                .seal(string.asData, using: key)
                .combined?
                .base64EncodedString()
        }
    }

    func decryptString(_ encryptedString: String, _ key: SymmetricKey, using: Algorithm = .AES_GCM) throws -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            Logger.shared.logError("Couldn't change String to Data", category: .encryption)
            throw EncryptionManagerError.stringEncodingError
        }

        do {
            switch using {
            case .ChaChaPoly:
                let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
                let decryptedData = try ChaChaPoly.open(sealedBox, using: key)
                return decryptedData.asString
            case .AES_GCM:
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                return decryptedData.asString
            }
        } catch CryptoKit.CryptoKitError.authenticationFailure {
            throw EncryptionManagerError.authenticationFailure
        }
    }

    func encryptData(_ data: Data, _ key: SymmetricKey, using: Algorithm = .AES_GCM) throws -> Data? {

        switch using {
        case .ChaChaPoly:
            return try ChaChaPoly.seal(data, using: key).combined
        case .AES_GCM:
            return try AES.GCM
                .seal(data, using: key)
                .combined
        }
    }

    func decryptData(_ encryptedData: Data, _ key: SymmetricKey, using: Algorithm = .AES_GCM) throws -> Data? {

        switch using {
        case .ChaChaPoly:
            let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedData)
            let decryptedData = try ChaChaPoly.open(sealedBox, using: key)
            return decryptedData
        case .AES_GCM:
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        }
    }
}
