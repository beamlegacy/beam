import Foundation
import BeamCore

enum PasswordManagerError: Error, Equatable {
    case wrongObjectsType
    case localPasswordNotFound
}

extension PasswordManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .wrongObjectsType:
            return "wrong objects type"
        case .localPasswordNotFound:
            return "local Password not found"
        }
    }
}

class PasswordManager {
    static var passwordsDBPath: String { BeamData.dataFolder(fileName: "passwords.db") }
}

extension PasswordManager: BeamObjectManagerDelegateProtocol {
    static var typeName: String { "password" }
    static var objectType: BeamObjectProtocol.Type { PasswordRecord.self }

    func receivedBeamObjects(_ objects: [BeamObject]) throws {
        let passwords: [PasswordRecord] = try objects.map {
            try $0.decodeBeamObject()
        }
        try receivedBeamObjects(passwords)
    }

    func receivedBeamObjects<T: BeamObjectProtocol>(_ objects: [T]) throws {
        guard let passwords: [PasswordRecord] = objects as? [PasswordRecord] else {
            throw PasswordManagerError.wrongObjectsType
        }

        Logger.shared.logDebug("Received \(passwords.count) passwords: updating",
                               category: .passwordNetwork)

        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        try passwordsDB.save(passwords: passwords)
    }

    func saveAllOnBeamObjectApi(_ completion: @escaping ((Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        let passwords = try passwordsDB.allRecords()

        return try saveOnBeamObjectsAPI(passwords, completion)
    }

    func saveOnBeamObjectAPI(_ object: BeamObjectProtocol,
                             _ completion: @escaping ((Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard let password = object as? PasswordRecord else {
            throw PasswordManagerError.wrongObjectsType
        }

        let objectManager = BeamObjectManager()

        return try objectManager.saveToAPI(password) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let updateBeamObject):
                do {
                    try self.saveOnBeamObjectsAPISuccess([updateBeamObject], completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectProtocol], _ completion: @escaping ((Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard let passwords = objects as? [PasswordRecord] else {
            throw PasswordManagerError.wrongObjectsType
        }

        let objectManager = BeamObjectManager()

        return try objectManager.saveToAPI(passwords) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Could not save all \(passwords.count) passwords: \(error.localizedDescription)",
                                       category: .passwordNetwork)
                completion(.failure(error))
            case .success(let updateBeamObjects):
                do {
                    try self.saveOnBeamObjectsAPISuccess(updateBeamObjects, completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Will store dataChecksum
    internal func saveOnBeamObjectsAPISuccess(_ updateBeamObjects: [PasswordRecord],
                                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws {
        Logger.shared.logDebug("Saved \(updateBeamObjects.count) objects on the BeamObject API",
                               category: .passwordNetwork)

        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        var passwords: [PasswordRecord] = []
        for updateBeamObject in updateBeamObjects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var password = try? passwordsDB.fetchWithId(updateBeamObject.beamObjectId) else {
                completion(.failure(PasswordManagerError.localPasswordNotFound))
                return
            }

            password.previousChecksum = updateBeamObject.previousChecksum
            passwords.append(password)
        }
        try passwordsDB.save(passwords: passwords)
        completion(.success(true))
    }
}
