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
    static var passwordsDBPath: String { BeamData.dataFolder(fileName: "passwords.db") }
}

extension PasswordManager: BeamObjectManagerDelegate {
    typealias BeamObjectType = PasswordRecord

    func receivedObjects(_ passwords: [PasswordRecord]) throws {
        Logger.shared.logDebug("Received \(passwords.count) passwords: updating",
                               category: .passwordNetwork)

        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        try passwordsDB.save(passwords: passwords)
    }

    func allObjects() throws -> [PasswordRecord] {
        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        let passwords = try passwordsDB.allRecords()
        return passwords
    }

    func persistChecksum(_ objects: [PasswordRecord], _ completion: @escaping ((Result<Bool, Error>) -> Void)) throws {
        Logger.shared.logDebug("Saved \(objects.count) passwords on the BeamObject API",
                               category: .passwordNetwork)

        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        var passwords: [PasswordRecord] = []
        for updateObject in objects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var password = try? passwordsDB.fetchWithId(updateObject.beamObjectId) else {
                completion(.failure(PasswordManagerError.localPasswordNotFound))
                return
            }

            password.previousChecksum = updateObject.previousChecksum
            passwords.append(password)
        }
        try passwordsDB.save(passwords: passwords)
        completion(.success(true))
    }
}
