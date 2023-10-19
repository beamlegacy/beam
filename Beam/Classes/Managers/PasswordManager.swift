import Foundation
import Combine
import BeamCore
import CryptoKit

final class PasswordManager {
    var changedObjects: [UUID: RemotePasswordRecord] = [:]
    let objectQueue = BeamObjectQueue<RemotePasswordRecord>()

    enum Error: Swift.Error {
        case databaseError(errorMsg: String)
        case decryptionError(errorMsg: String)
        case encryptionError(errorMsg: String)

        var localizedDescription: String {
            switch self {
            case .databaseError(let errorMsg), .decryptionError(let errorMsg), .encryptionError(let errorMsg):
                return errorMsg
            }
        }
    }

    struct SanityDigest: Equatable {
        var total: Int
        var deleted: Int
        var readableValidSignature: Int
        var readableInvalidSignature: Int
        var unreadableValidSignature: Int
        var unreadableInvalidSignature: Int

        var isValid: Bool {
            total == deleted + readableValidSignature
        }

        var description: String {
            """
            Total records: \(total), deleted: \(deleted)
            \(readableValidSignature + readableInvalidSignature) readable (\(readableInvalidSignature) invalid signatures)
            \(unreadableValidSignature + unreadableInvalidSignature) unreadable (\(unreadableInvalidSignature) invalid signatures)
            """
        }
    }

    var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    private var hostnameCanonicalizer: HostnameCanonicalizer
    private var overridePasswordDB: PasswordStore?
    private var passwordsDB: PasswordStore? { overridePasswordDB ?? BeamData.shared.passwordDB }
    private var changeSubject: PassthroughSubject<Void, Never>

    let objectManager: BeamObjectManager

    init(overridePasswordDB: PasswordStore? = nil,
         hostLookup: HostnameCanonicalizer = .shared,
         objectManager: BeamObjectManager) {
        self.overridePasswordDB = overridePasswordDB
        self.hostnameCanonicalizer = hostLookup
        self.changeSubject = PassthroughSubject<Void, Never>()
        self.objectManager = objectManager

        registerOnBeamObjectManager(objectManager)
    }

    private func passwordManagerEntries(for passwordsRecord: [LocalPasswordRecord]) -> [PasswordManagerEntry] {
        passwordsRecord.map { PasswordManagerEntry(minimizedHost: $0.hostname, username: $0.username, neverSaved: $0.disabledForHost) }
    }

    func fetchAll() -> [PasswordManagerEntry] {
        do {
            guard let allEntries = try passwordsDB?.fetchAll() else {
                return []
            }
            return passwordManagerEntries(for: allEntries)
        } catch PasswordDBError.errorFetchingPassword(let errorMsg) {
            Logger.shared.logError("Error while fetching all passwords: \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func entries(for host: String, options: PasswordManagerHostLookupOptions) -> [PasswordManagerEntry] {
        do {
            let allRecords = try records(for: host, options: options)
            let enabledRecords = allRecords.filter { !$0.disabledForHost }
            return passwordManagerEntries(for: enabledRecords)
        } catch PasswordDBError.errorFetchingPassword(let errorMsg) {
            Logger.shared.logError("Error while fetching password entries for \(host): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func records(for host: String, options: PasswordManagerHostLookupOptions) throws -> [LocalPasswordRecord] {
        guard let passwordsDB = passwordsDB else {
            throw Error.databaseError(errorMsg: "database not available")
        }
        let canonicalHost = options.contains(.genericHost) ? hostnameCanonicalizer.canonicalHostname(for: host) : nil
        let hostGroup = options.contains(.sharedCredentials) ? hostnameCanonicalizer.hostsSharingCredentials(with: canonicalHost ?? host) : nil
        let records: [LocalPasswordRecord]
        if let hostGroup = hostGroup {
            records = try hostGroup.flatMap {
                try passwordsDB.entries(for: $0, options: .exact)
            }
        } else if let canonicalHost = canonicalHost {
            records = try passwordsDB.entries(for: canonicalHost, options: .subdomains)
        } else {
            records = try passwordsDB.entries(for: host, options: options)
        }
        return records
    }

    func bestMatchingEntries(hostname: String, username: String) -> [PasswordManagerEntry] {
        entries(for: hostname, options: .fuzzy)
            .filter { username.hasPrefix($0.username) }
            .sorted(by: { $0.username.count > $1.username.count })
    }

    func bestMatchingEntry(hostname: String, exactUsername username: String) -> PasswordManagerEntry? {
        var matchingEntries = entries(for: hostname, options: .fuzzy)
            .filter { username == $0.username }
        if matchingEntries.count > 1 {
            matchingEntries = matchingEntries.filter { $0.minimizedHost == hostname }
        }
        return matchingEntries.first
    }

    func credentials(for host: String, completion: @escaping ([Credential]) -> Void) {
        guard let passwordsDB = passwordsDB else {
            completion([])
            return
        }

        return passwordsDB.credentials(for: host) { credentials in
            completion(credentials)
        }
    }

    func password(hostname: String, username: String, markUsed: Bool = false) throws -> String {
        do {
            guard let passwordsDB = passwordsDB, let passwordRecord = try passwordsDB.passwordRecord(hostname: hostname, username: username) else {
                throw PasswordDBError.cantReadDB(errorMsg: "Database returned no entry")
            }
            guard let decryptedPassword = try EncryptionManager.shared.decryptString(passwordRecord.password, EncryptionManager.shared.localPrivateKey()) else {
                throw Error.decryptionError(errorMsg: "Decrypting password returned nil")
            }
            if markUsed, let updatedRecord = try? passwordsDB.markUsed(record: passwordRecord) {
                if AuthenticationManager.shared.isAuthenticated {
                    saveOnNetwork(updatedRecord)
                }
            }
            return decryptedPassword
        } catch Error.decryptionError(let errorMsg) {
            Logger.shared.logError("Error while decrypting password for \(hostname) - \(username): \(errorMsg)", category: .encryption)
            throw Error.decryptionError(errorMsg: errorMsg)
        } catch PasswordDBError.cantReadDB(let errorMsg) {
            Logger.shared.logError("Error while reading database for \(hostname) - \(username): \(errorMsg)", category: .passwordsDB)
            throw Error.databaseError(errorMsg: errorMsg)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
            throw Error.databaseError(errorMsg: error.localizedDescription)
        }
    }

    func isSaveDisabled(forHost hostname: String) -> Bool {
        guard let records = try? records(for: hostname, options: .exact) else { return false }
        return records.contains(where: { $0.disabledForHost })
    }

    @discardableResult
    func save(entry: PasswordManagerEntry? = nil,
              hostname: String,
              username: String,
              password: String,
              disabledForHost: Bool = false,
              uuid: UUID? = nil,
              _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) -> LocalPasswordRecord? {
        guard let passwordsDB = passwordsDB else {
            networkCompletion?(.failure(BeamDataError.databaseNotFound))
            return nil
        }

        do {
            let previousHostname: String
            let previousUsername: String
            if let entry = entry {
                previousHostname = entry.minimizedHost
                previousUsername = entry.username
            } else {
                previousHostname = hostname
                previousUsername = username
            }
            guard let encryptedPassword = try? EncryptionManager.shared.encryptString(password, EncryptionManager.shared.localPrivateKey()) else {
                throw Error.encryptionError(errorMsg: "encryption failed")
            }
            let privateKeySignature = try EncryptionManager.shared.localPrivateKey().asString().SHA256()
            var passwordRecord: LocalPasswordRecord
            if let previousRecord = try? passwordsDB.passwordRecord(hostname: previousHostname, username: previousUsername) {
                passwordRecord = try passwordsDB.update(record: previousRecord, hostname: hostname, username: username, encryptedPassword: encryptedPassword, privateKeySignature: privateKeySignature, uuid: uuid)
            } else {
                passwordRecord = try passwordsDB.save(hostname: hostname, username: username, encryptedPassword: encryptedPassword, disabledForHost: disabledForHost, privateKeySignature: privateKeySignature, uuid: uuid)
            }
            passwordRecord = (try? passwordsDB.markUsed(record: passwordRecord)) ?? passwordRecord
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated {
                self.saveOnNetwork(passwordRecord, networkCompletion)
            } else {
                networkCompletion?(.success(false))
            }
            return passwordRecord
        } catch PasswordDBError.cantSavePassword(let errorMsg) {
            Logger.shared.logError("Error while saving password for \(hostname): \(errorMsg)", category: .passwordsDB)
        } catch Error.encryptionError {
            Logger.shared.logError("Error while encrypting password for \(hostname) - \(username)", category: .encryption)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        networkCompletion?(.success(false))
        return nil
    }

    func find(_ searchString: String) -> [PasswordManagerEntry] {
        guard let passwordsDB = passwordsDB else { return [] }
        do {
            let entries = try passwordsDB.find(searchString)
            return passwordManagerEntries(for: entries)
        } catch PasswordDBError.errorSearchingPassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while searching password for \(searchString): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func markDeleted(hostname: String, for username: String, _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) {
        guard let passwordsDB = passwordsDB else {
            networkCompletion?(.failure(BeamDataError.databaseNotFound))
            return
        }
        do {
            let passwordRecord = try passwordsDB.markDeleted(hostname: hostname, username: username)
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated {
                self.saveOnNetwork(passwordRecord, networkCompletion)
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch PasswordDBError.cantDeletePassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting password for \(hostname) - \(username): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        networkCompletion?(.success(false))
    }

    func markAllDeleted(_ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) {
        guard let passwordsDB = passwordsDB else {
            networkCompletion?(.failure(BeamDataError.databaseNotFound))
            return
        }
        do {
            let passwordsRecord = try passwordsDB.markAllDeleted()
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated {
                self.saveAllOnNetwork(passwordsRecord, networkCompletion)
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch PasswordDBError.cantDeletePassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all passwords: \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        networkCompletion?(.success(false))
    }

    func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) {
        do {
            guard let passwordsDB = passwordsDB else {
                networkCompletion?(.failure(BeamDataError.databaseNotFound))
                return
            }

            try passwordsDB.deleteAll()
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                Task {
                    do {
                        try await self.deleteAllFromBeamObjectAPI()
                        networkCompletion?(.success(true))
                    } catch {
                        Logger.shared.logError("Error while deleting all contacts: \(error)", category: .contactsDB)
                        networkCompletion?(.success(false))
                    }
                }
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch PasswordDBError.cantDeletePassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all passwords: \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        networkCompletion?(.success(false))
    }

    func count() -> Int {
        fetchAll().count
    }

    func sanityDigest() throws -> SanityDigest {
        let localPrivateKeySignature = try EncryptionManager.shared.localPrivateKey().asString().SHA256()
        let allRecords = try passwordsDB?.fetchAll() ?? []
        var digest = SanityDigest(total: allRecords.count, deleted: 0, readableValidSignature: 0, readableInvalidSignature: 0, unreadableValidSignature: 0, unreadableInvalidSignature: 0)
        for record in allRecords {
            if record.deletedAt == nil {
                let validSignature = record.privateKeySignature == localPrivateKeySignature
                let password = try? EncryptionManager.shared.decryptString(record.password, EncryptionManager.shared.localPrivateKey())
                let readablePassword = password?.isEmpty == false
                if readablePassword {
                    if validSignature {
                        digest.readableValidSignature += 1
                    } else {
                        digest.readableInvalidSignature += 1
                    }
                } else {
                    if validSignature {
                        digest.unreadableValidSignature += 1
                    } else {
                        digest.unreadableInvalidSignature += 1
                    }
                }
            } else {
                digest.deleted += 1
            }
        }
        return digest
    }

    func deleteUnrecoverablePasswords() throws {
        let localPrivateKey = try EncryptionManager.shared.localPrivateKey()
        let allRecords = try passwordsDB?.fetchAll() ?? []
        for record in allRecords.filter({ $0.deletedAt == nil }) {
            let password = try? EncryptionManager.shared.decryptString(record.password, localPrivateKey)
            if password?.isEmpty != false { // password is nil or empty
                markDeleted(hostname: record.hostname, for: record.username)
            }
        }
    }
}

// MARK: - BeamObjectManagerDelegate
extension PasswordManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    static var uploadType: BeamObjectRequestUploadType {
        Configuration.directUploadAllObjects ? .directUpload : .multipartUpload
    }
    func willSaveAllOnBeamObjectApi() {}

    func saveObjectsAfterConflict(_ passwords: [RemotePasswordRecord]) throws {
        guard let passwordsDB = passwordsDB else {
            throw BeamDataError.databaseNotFound
        }
        let localPasswords = passwords.compactMap(PasswordEncryptionManager.laxReEncryptAfterReceive)
        if localPasswords.count != passwords.count {
            Logger.shared.logError(Error.decryptionError(errorMsg: "Key mismatch, affected passwords: \(passwords.count - localPasswords.count)/\(passwords.count)").localizedDescription, category: .tracking)
        }
        try passwordsDB.save(passwords: localPasswords)
        changeSubject.send()
    }

    func manageConflict(_ dbStruct: RemotePasswordRecord,
                        _ remoteDbStruct: RemotePasswordRecord) throws -> RemotePasswordRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func receivedObjects(_ passwords: [RemotePasswordRecord]) throws {
        guard let passwordsDB = passwordsDB else {
            throw BeamDataError.databaseNotFound
        }

        let localPasswords = passwords.compactMap(PasswordEncryptionManager.laxReEncryptAfterReceive)
        if localPasswords.count != passwords.count {
            Logger.shared.logError(Error.decryptionError(errorMsg: "Key mismatch, affected passwords: \(passwords.count - localPasswords.count)/\(passwords.count)").localizedDescription, category: .tracking)
        }
        try passwordsDB.save(passwords: localPasswords)
        changeSubject.send()
    }

    func allObjects(updatedSince: Date?) throws -> [RemotePasswordRecord] {
        guard let passwordsDB = passwordsDB else {
            throw BeamDataError.databaseNotFound
        }

        let localPasswords = try passwordsDB.allRecords(updatedSince)
        return try localPasswords.map(PasswordEncryptionManager.reEncryptBeforeSend)
    }

    func saveAllOnNetwork(_ passwords: [LocalPasswordRecord], _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) {
        let networkPasswords = passwords.compactMap(PasswordEncryptionManager.tryReEncryptBeforeSend)
        if networkPasswords.count != passwords.count {
            Logger.shared.logError(Error.decryptionError(errorMsg: "Key mismatch, affected passwords: \(passwords.count - networkPasswords.count)/\(passwords.count)").localizedDescription, category: .tracking)
        }
        Task.detached(priority: .userInitiated) { [self] in
            do {
                try await saveOnBeamObjectsAPI(networkPasswords)
                Logger.shared.logDebug("Saved passwords on the BeamObject API",
                                       category: .passwordNetwork)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the passwords on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .passwordNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ password: LocalPasswordRecord, _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) {
        do {
            let networkPassword = try PasswordEncryptionManager.reEncryptBeforeSend(password)
            Task.detached(priority: .userInitiated) { [self] in
                do {
                    try await saveOnBeamObjectAPI(networkPassword)
                    Logger.shared.logDebug("Saved password on the BeamObject API",
                                           category: .passwordNetwork)
                    networkCompletion?(.success(true))
                } catch {
                    Logger.shared.logWarning("Saving the password on the BeamObject API failed with error: \(error.localizedDescription)",
                                             category: .passwordNetwork)
                    networkCompletion?(.failure(error))
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .passwordNetwork)
            networkCompletion?(.failure(error))
        }
    }
}
