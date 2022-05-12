import Foundation
import Combine
import BeamCore
import CryptoKit

class PasswordManager {
    enum Error: Swift.Error {
        case databaseError(errorMsg: String)
        case decryptionError(errorMsg: String)
    }

    static let shared = PasswordManager()
    static var passwordsDBPath: String { BeamData.dataFolder(fileName: "passwords.db") }

    var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    private var hostnameCanonicalizer: HostnameCanonicalizer
    private var passwordsDB: PasswordStore
    private var changeSubject: PassthroughSubject<Void, Never>

    convenience init() {
        do {
            let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
            self.init(passwordsDB: passwordsDB, hostLookup: .shared)
        } catch {
            fatalError("Error while creating the Passwords Database \(error)")
        }
    }

    init(passwordsDB: PasswordStore, hostLookup: HostnameCanonicalizer = .shared) {
        self.hostnameCanonicalizer = hostLookup
        self.passwordsDB = passwordsDB
        self.changeSubject = PassthroughSubject<Void, Never>()
    }

    private func passwordManagerEntries(for passwordsRecord: [PasswordRecord]) -> [PasswordManagerEntry] {
        passwordsRecord.map { PasswordManagerEntry(minimizedHost: $0.hostname, username: $0.username) }
    }

    func fetchAll() -> [PasswordManagerEntry] {
        do {
            let allEntries = try passwordsDB.fetchAll()
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
            let canonicalHost = options.contains(.genericHost) ? hostnameCanonicalizer.canonicalHostname(for: host) : nil
            let hostGroup = options.contains(.sharedCredentials) ? hostnameCanonicalizer.hostsSharingCredentials(with: canonicalHost ?? host) : nil
            let records: [PasswordRecord]
            if let hostGroup = hostGroup {
                records = try hostGroup.flatMap {
                    try passwordsDB.entries(for: $0, options: .exact)
                }
            } else if let canonicalHost = canonicalHost {
                records = try passwordsDB.entries(for: canonicalHost, options: .subdomains)
            } else {
                records = try passwordsDB.entries(for: host, options: options)
            }
            return passwordManagerEntries(for: records)
        } catch PasswordDBError.errorFetchingPassword(let errorMsg) {
            Logger.shared.logError("Error while fetching password entries for \(host): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func bestMatchingEntries(hostname: String, username: String) -> [PasswordManagerEntry] {
        entries(for: hostname, options: .fuzzy)
            .filter { username.hasPrefix($0.username) }
            .sorted(by: { $0.username.count > $1.username.count })
    }

    func credentials(for host: String, completion: @escaping ([Credential]) -> Void) {
        passwordsDB.credentials(for: host) { credentials in
            completion(credentials)
        }
    }

    func password(hostname: String, username: String) throws -> String {
        do {
            guard let password = try passwordsDB.password(hostname: hostname, username: username) else {
                throw PasswordDBError.cantReadDB(errorMsg: "Database returned no entry")
            }
            return password
        } catch PasswordDBError.cantDecryptPassword(let errorMsg) {
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

    @discardableResult
    func save(entry: PasswordManagerEntry? = nil,
              hostname: String,
              username: String,
              password: String,
              uuid: UUID? = nil,
              _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) -> PasswordRecord? {
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
            let passwordRecord: PasswordRecord
            if let previousRecord = try? passwordsDB.passwordRecord(hostname: previousHostname, username: previousUsername) {
                passwordRecord = try passwordsDB.update(record: previousRecord, hostname: hostname, username: username, password: password, uuid: uuid)
            } else {
                passwordRecord = try passwordsDB.save(hostname: hostname, username: username, password: password, uuid: uuid)
            }
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated {
                try self.saveOnNetwork(passwordRecord, networkCompletion)
            } else {
                networkCompletion?(.success(false))
            }
            return passwordRecord
        } catch PasswordDBError.cantSavePassword(let errorMsg) {
            Logger.shared.logError("Error while saving password for \(hostname): \(errorMsg)", category: .passwordsDB)
        } catch PasswordDBError.cantEncryptPassword {
            Logger.shared.logError("Error while encrypting password for \(hostname) - \(username)", category: .encryption)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        networkCompletion?(.success(false))
        return nil
    }

    func find(_ searchString: String) -> [PasswordManagerEntry] {
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
        do {
            let passwordRecord = try passwordsDB.markDeleted(hostname: hostname, username: username)
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated {
                try self.saveOnNetwork(passwordRecord, networkCompletion)
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
        do {
            let passwordsRecord = try passwordsDB.markAllDeleted()
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated {
                try self.saveAllOnNetwork(passwordsRecord, networkCompletion)
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
            try passwordsDB.deleteAll()
            changeSubject.send()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                try self.deleteAllFromBeamObjectAPI { result in
                    networkCompletion?(result)
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
}

extension PasswordManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue = DispatchQueue(label: "PasswordManager BeamObjectManager backgroundQueue", qos: .userInitiated)
    func willSaveAllOnBeamObjectApi() {}

    func saveObjectsAfterConflict(_ passwords: [PasswordRecord]) throws {
        var encryptedsPasswords: [PasswordRecord] = []
        for password in passwords {
            encryptedsPasswords.append(reEncrypt(password, encryptKey: EncryptionManager.shared.localPrivateKey()))
        }
        try self.passwordsDB.save(passwords: encryptedsPasswords)
        changeSubject.send()
    }

    func manageConflict(_ dbStruct: PasswordRecord,
                        _ remoteDbStruct: PasswordRecord) throws -> PasswordRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func receivedObjects(_ passwords: [PasswordRecord]) throws {
        var encryptedsPasswords: [PasswordRecord] = []
        for password in passwords {
            encryptedsPasswords.append(reEncrypt(password, encryptKey: EncryptionManager.shared.localPrivateKey()))
        }

        try self.passwordsDB.save(passwords: encryptedsPasswords)
        changeSubject.send()
    }

    func allObjects(updatedSince: Date?) throws -> [PasswordRecord] {
        try self.passwordsDB.allRecords(updatedSince)
    }

    func saveAllOnNetwork(_ passwords: [PasswordRecord], _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) throws {
        let encryptedsPasswords = passwords.map { password in
            reEncrypt(password, decryptKey: EncryptionManager.shared.localPrivateKey())
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.saveOnBeamObjectsAPI(encryptedsPasswords)
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

    private func saveOnNetwork(_ password: PasswordRecord, _ networkCompletion: ((Result<Bool, Swift.Error>) -> Void)? = nil) throws {
        let encryptedPassword = reEncrypt(password, decryptKey: EncryptionManager.shared.localPrivateKey())
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.saveOnBeamObjectAPI(encryptedPassword)
                Logger.shared.logDebug("Saved password on the BeamObject API",
                                       category: .passwordNetwork)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the password on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .passwordNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func reEncrypt(_ password: PasswordRecord, decryptKey: SymmetricKey? = nil, encryptKey: SymmetricKey? = nil) -> PasswordRecord {
        var passwordRecord = password
        if let decryptedPassword = try? EncryptionManager.shared.decryptString(passwordRecord.password, decryptKey),
           let newlyEncryptedPassword = try? EncryptionManager.shared.encryptString(decryptedPassword, encryptKey) {
               passwordRecord.password = newlyEncryptedPassword
        }
        return passwordRecord
    }
}
