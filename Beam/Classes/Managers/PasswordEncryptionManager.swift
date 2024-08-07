//
//  PasswordEncryptionManager.swift
//  Beam
//
//  Created by Frank Lefebvre on 27/06/2022.
//

import BeamCore
import CryptoKit

enum PasswordEncryptionManager {
        static func laxReEncryptAfterReceive(_ networkPassword: RemotePasswordRecord) -> LocalPasswordRecord? {
            if let localPassword = tryReEncryptAfterReceive(networkPassword) {
                return localPassword
            }
            if let localPrivateKey = try? EncryptionManager.shared.localPrivateKey(), let privateKeySignature = try? localPrivateKey.asString().SHA256(), (try? EncryptionManager.shared.decryptString(networkPassword.password, localPrivateKey)) != nil {
                Logger.shared.logWarning("Network password was encrypted with valid local key: \(networkPassword.hostname)", category: .passwordNetwork)
                return LocalPasswordRecord(uuid: networkPassword.uuid, entryId: networkPassword.entryId, hostname: networkPassword.hostname, username: networkPassword.username, password: networkPassword.password, disabledForHost: networkPassword.disabledForHost, createdAt: networkPassword.createdAt, updatedAt: networkPassword.updatedAt, usedAt: networkPassword.usedAt, deletedAt: networkPassword.deletedAt, privateKeySignature: privateKeySignature)
            }
            Logger.shared.logError("Network password can't be decrypted with either remote or local key, deleting: \(networkPassword.hostname)", category: .passwordNetwork)
            return nil
        }

        static func tryReEncryptAfterReceive(_ networkPassword: RemotePasswordRecord) -> LocalPasswordRecord? {
            try? reEncryptAfterReceive(networkPassword)
        }

        static func reEncryptAfterReceive(_ networkPassword: RemotePasswordRecord) throws -> LocalPasswordRecord {
            do {
                let password = try reEncrypt(networkPassword.password, deleted: networkPassword.deletedAt != nil, encryptKey: EncryptionManager.shared.localPrivateKey())
                let privateKeySignature = try EncryptionManager.shared.localPrivateKey().asString().SHA256()
                return LocalPasswordRecord(uuid: networkPassword.uuid, entryId: networkPassword.entryId, hostname: networkPassword.hostname, username: networkPassword.username, password: password, disabledForHost: networkPassword.disabledForHost, createdAt: networkPassword.createdAt, updatedAt: networkPassword.updatedAt, usedAt: networkPassword.usedAt, deletedAt: networkPassword.deletedAt, privateKeySignature: privateKeySignature)
            } catch {
                Logger.shared.logError("Converting received password failed for \(networkPassword.hostname): \(error.localizedDescription)", category: .passwordNetwork)
                throw error
            }
        }

        static func tryReEncryptBeforeSend(_ localPassword: LocalPasswordRecord) -> RemotePasswordRecord? {
            try? reEncryptBeforeSend(localPassword)
        }

        static func reEncryptBeforeSend(_ localPassword: LocalPasswordRecord) throws -> RemotePasswordRecord {
            do {
                let password = try reEncrypt(localPassword.password, deleted: localPassword.deletedAt != nil, decryptKey: EncryptionManager.shared.localPrivateKey())
                let privateKeySignature = try EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString().SHA256()
                return RemotePasswordRecord(uuid: localPassword.uuid, entryId: localPassword.entryId, hostname: localPassword.hostname, username: localPassword.username, password: password, disabledForHost: localPassword.disabledForHost, createdAt: localPassword.createdAt, updatedAt: localPassword.updatedAt, usedAt: localPassword.usedAt, deletedAt: localPassword.deletedAt, privateKeySignature: privateKeySignature)
            } catch {
                Logger.shared.logError("Converting password before sending failed for \(localPassword.hostname): \(error.localizedDescription)", category: .passwordNetwork)
                throw error
            }
        }

        private static func reEncrypt(_ password: String, deleted: Bool = false, decryptKey: SymmetricKey? = nil, encryptKey: SymmetricKey? = nil) throws -> String {
            guard let decryptedPassword = (deleted ? "" : try EncryptionManager.shared.decryptString(password, decryptKey)) else {
                throw EncryptionManagerError.stringDecodingError
            }
            guard let newlyEncryptedPassword = try EncryptionManager.shared.encryptString(decryptedPassword, encryptKey) else {
                throw EncryptionManagerError.internalEncryptionError
            }
            return newlyEncryptedPassword
        }
}
