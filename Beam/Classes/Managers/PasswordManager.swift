import Foundation
import BeamCore

enum PasswordManagerError: Error, Equatable {
    case localPasswordNotFound
}

extension PasswordManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .localPasswordNotFound:
            return "local Password not found"
        }
    }
}

class PasswordManager {
    static let shared = PasswordManager()
    static var passwordsDBPath: String { BeamData.dataFolder(fileName: "passwords.db") }

    private var passwordsDB: PasswordsDB

    init() {
        do {
            passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        } catch {
            fatalError("Error while creating the Passwords Database \(error)")
        }
    }

    private func managerEntries(for passwordsRecord: [PasswordRecord]) -> [PasswordManagerEntry] {
        passwordsRecord.map { PasswordManagerEntry(minimizedHost: $0.host, username: $0.name) }
    }

    func fetchAll() -> [PasswordManagerEntry] {
        do {
            let allEntries = try passwordsDB.fetchAll()
            return self.managerEntries(for: allEntries)
        } catch PasswordDBError.errorFetchingPassword(let errorMsg) {
            Logger.shared.logError("Error while fetching all passwords: \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func entries(for host: String, exact: Bool) -> [PasswordManagerEntry] {
        do {
            let entries = try passwordsDB.entries(for: host, exact: exact)
            return self.managerEntries(for: entries)
        } catch PasswordDBError.errorFetchingPassword(let errorMsg) {
            Logger.shared.logError("Error while fetching password entries for \(host): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func credentials(for host: String, completion: @escaping ([Credential]) -> Void) {
        passwordsDB.credentials(for: host) { credentials in
            completion(credentials)
        }
    }

    func password(host: String, username: String ) -> String? {
        do {
            let password = try passwordsDB.password(host: host, username: username)
            return password
        } catch PasswordDBError.cantDecryptPassword(let errorMsg) {
            Logger.shared.logError("Error while decrypting password for \(host) - \(username): \(errorMsg)", category: .encryption)
        } catch PasswordDBError.cantReadDB(let errorMsg) {
            Logger.shared.logError("Error while reading database for \(host) - \(username): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return nil
    }

    func save(host: String, username: String, password: String) {
        do {
            let passwordRecord = try passwordsDB.save(host: host, username: username, password: password)
            if AuthenticationManager.shared.isAuthenticated {
                try? self.save(passwordRecord)
            }
        } catch PasswordDBError.cantSavePassword(let errorMsg) {
            Logger.shared.logError("Error while saving password for \(host): \(errorMsg)", category: .passwordsDB)
        } catch PasswordDBError.cantEncryptPassword {
            Logger.shared.logError("Error while encrypting password for \(host) - \(username)", category: .encryption)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
    }

    func find(_ searchString: String) -> [PasswordManagerEntry] {
        do {
            let entries = try passwordsDB.find(searchString)
            return managerEntries(for: entries)
        } catch PasswordDBError.errorSearchingPassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while searching password for \(searchString): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
        return []
    }

    func delete(host: String, for username: String) {
        do {
            let passwordRecord = try passwordsDB.delete(host: host, username: username)
            if AuthenticationManager.shared.isAuthenticated {
                try self.save(passwordRecord)
            }
        } catch PasswordDBError.cantDeletePassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting password for \(host) - \(username): \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
    }

    func deleteAll() {
        do {
            let passwordsRecord = try passwordsDB.deleteAll()
            if AuthenticationManager.shared.isAuthenticated {
                try self.saveAll(passwordsRecord)
            }
        } catch PasswordDBError.cantDeletePassword(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all passwords: \(errorMsg)", category: .passwordsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .passwordsDB)
        }
    }
}

extension PasswordManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ passwords: [PasswordRecord]) throws {
        Logger.shared.logDebug("Received \(passwords.count) passwords: updating",
                               category: .passwordNetwork)

        try self.passwordsDB.save(passwords: passwords)
    }

    func allObjects() throws -> [PasswordRecord] {
        let passwords = try self.passwordsDB.allRecords()
        return passwords
    }

    func saveAll(_ passwords: [PasswordRecord]) throws {
        try self.saveOnBeamObjectsAPI(passwords) { result in
            switch result {
            case .success:
                Logger.shared.logDebug("Saved passwords on the BeamObject API",
                                       category: .passwordNetwork)
            case .failure(let error):
                Logger.shared.logDebug("Error when saving the passwords on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .passwordNetwork)
            }
        }
    }

    private func save(_ password: PasswordRecord) throws {
        try self.saveOnBeamObjectAPI(password) { result in
            switch result {
            case .success:
                Logger.shared.logDebug("Saved password on the BeamObject API",
                                       category: .passwordNetwork)
            case .failure(let error):
                Logger.shared.logDebug("Error when saving the password on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .passwordNetwork)
            }
        }
    }

    func persistChecksum(_ objects: [PasswordRecord]) throws {
        Logger.shared.logDebug("Saved \(objects.count) passwords on the BeamObject API",
                               category: .passwordNetwork)

        var passwords: [PasswordRecord] = []
        for updateObject in objects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var password = try? self.passwordsDB.fetchWithId(updateObject.beamObjectId) else {
                throw PasswordManagerError.localPasswordNotFound
            }

            password.previousChecksum = updateObject.previousChecksum
            passwords.append(password)
        }
        try self.passwordsDB.save(passwords: passwords)
    }
}
