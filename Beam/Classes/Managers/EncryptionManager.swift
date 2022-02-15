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
    private var lock = RWLock()

    enum Algorithm: String, CaseIterable {
        case ChaChaPoly
        case AES_GCM
    }

    func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    // MARK: - Private Keys
    func clearPrivateKey(for email: String) {
        lock.write {
            guard var privateKeys = Persistence.Encryption.privateKeys else { return }

            privateKeys.removeValue(forKey: email)
            Persistence.Encryption.privateKeys = privateKeys
            Persistence.Encryption.updateDate = BeamDate.now

            Logger.shared.logWarning("Private key for user \(email) has been cleared", category: .encryption)
        }
    }

    func resetPrivateKeys(andMigrateOldSharedKey: Bool) {
        lock.write {
            Logger.shared.logWarning("Private keys has been reset", category: .encryption)
            if andMigrateOldSharedKey {
                Persistence.Encryption.privateKeys = [:]
                if let email = Persistence.Authentication.email {
                    _ = self.privateKey(for: email)
                } else {
                    Persistence.Encryption.updateDate = BeamDate.now
                }
            } else {
                Persistence.Encryption.privateKeys = nil
                Persistence.Encryption.updateDate = BeamDate.now
            }
        }
    }

    func replacePrivateKey(for email: String, with base64EncodedString: String) throws {
        try lock.write {
            guard let key = SymmetricKey(base64EncodedString: base64EncodedString) else {
                throw EncryptionManagerError.keyError
            }

            guard var privateKeys = Persistence.Encryption.privateKeys else { return }

            privateKeys.updateValue(key.asString(), forKey: email)

            Persistence.Encryption.privateKeys = privateKeys
            Persistence.Encryption.updateDate = BeamDate.now

            Logger.shared.logWarning("Private key for user \(email) has been replaced", category: .encryption)
        }
    }

    @discardableResult
    func privateKey(for email: String) -> SymmetricKey {
        guard !email.isEmpty else {
            fatalError("No Email provided to get PrivateKey, it should never happen")
        }

        return lock.write {
            if let privateKeys = Persistence.Encryption.privateKeys,
               let privateKeyData = privateKeys[email],
               let result = SymmetricKey(base64EncodedString: privateKeyData) {
                return result
            } else if let privateKeys = Persistence.Encryption.privateKeys,
                      let oldPrivateKey = Persistence.Encryption.privateKey,
                      !privateKeys.contains(where: { $0.value == oldPrivateKey }),
                      let oldSymmetricKey = SymmetricKey(base64EncodedString: oldPrivateKey) {
                Logger.shared.logWarning("Private key for user \(email) doesn't exist, fetching old private key",
                                         category: .encryption)

                self.savePrivateKey(for: email, with: oldPrivateKey)

                return oldSymmetricKey
            } else {
                Logger.shared.logWarning("Private key for user \(email) doesn't exist, creating new one",
                                         category: .encryption)
                let key = self.generateKey()
                self.savePrivateKey(for: email, with: key.asString())
                return key
            }
        }
    }

    var accounts: [String] {
        return lock.read {
            guard let pkeys =  Persistence.Encryption.privateKeys else { return [] }
            return Array(pkeys.keys)
        }
    }

    private func savePrivateKey(for email: String, with key: String) {
        lock.write {
            if var privateKeys = Persistence.Encryption.privateKeys {
                privateKeys.updateValue(key, forKey: email)
                Persistence.Encryption.privateKeys = privateKeys
            } else {
                Persistence.Encryption.privateKeys = [email: key]
                Persistence.Encryption.creationDate = BeamDate.now

            }
            Persistence.Encryption.updateDate = BeamDate.now
        }
    }

    // MARK: - Local Private Key
    @discardableResult
    func localPrivateKey() -> SymmetricKey {
        return lock.write {
            if let localDataKey = Persistence.Encryption.localPrivateKey,
               let localPrivateKey = SymmetricKey(base64EncodedString: localDataKey) {
                return localPrivateKey
            }
            Logger.shared.logWarning("Local Private key doesn't exist or has a wrong format: \(Persistence.Encryption.localPrivateKey ?? "-"), creating new one",
                                     category: .encryption)

            var key: SymmetricKey
            if let dataKey = Persistence.Encryption.privateKey,
               let privateKey = SymmetricKey(base64EncodedString: dataKey) {
                key = privateKey
            } else {
                key = self.generateKey()
            }
            Persistence.Encryption.localPrivateKey = key.asString()
            return key
        }
    }

    // MARK: - Encrypt / Decrypt
    func encryptString(_ string: String, _ key: SymmetricKey? = nil, using: Algorithm = .AES_GCM) throws -> String? {
        let key = key ?? privateKey(for: Persistence.emailOrRaiseError())
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

    func decryptString(_ encryptedString: String, _ key: SymmetricKey? = nil, using: Algorithm = .AES_GCM) throws -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            Logger.shared.logError("Couldn't change String to Data", category: .encryption)
            throw EncryptionManagerError.stringEncodingError
        }
        let key = key ?? privateKey(for: Persistence.emailOrRaiseError())

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

    func encryptData(_ data: Data, _ key: SymmetricKey? = nil, using: Algorithm = .AES_GCM) throws -> Data? {
        let key = key ?? privateKey(for: Persistence.emailOrRaiseError())

        switch using {
        case .ChaChaPoly:
            return try ChaChaPoly.seal(data, using: key).combined
        case .AES_GCM:
            return try AES.GCM
                .seal(data, using: key)
                .combined
        }
    }

    func decryptData(_ encryptedData: Data, _ key: SymmetricKey? = nil, using: Algorithm = .AES_GCM) throws -> Data? {
        let key = key ?? privateKey(for: Persistence.emailOrRaiseError())

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
