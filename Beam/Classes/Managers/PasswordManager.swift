import Foundation
import BeamCore

enum PasswordManagerError: Error, Equatable {
    case wrongObjectsType
    case localDocumentNotFound
}

extension PasswordManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .wrongObjectsType:
            return "wrong objects type"
        case .localDocumentNotFound:
            return "local Password not found"
        }
    }
}

class PasswordManager {
    static var passwordsDBPath: String { BeamData.dataFolder(fileName: "passwords.db") }

    required init(_ manager: BeamObjectManager) {
    }
}

extension PasswordManager: BeamObjectManagerDelegateProtocol {
    static var typeName: String { "password" }

    func receivedBeamObjects(_ objects: [BeamObject]) throws {
        let passwords: [PasswordRecord] = try objects.map {
            try $0.decodeBeamObject()
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

        let beamObject = try BeamObject(password, Self.typeName)

        let objectManager = BeamObjectManager()

        return try objectManager.saveToAPI(beamObject) { result in
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

        let beamObjects = try BeamObjectManagerDelegate().structsAsBeamObjects(passwords)

        guard !beamObjects.isEmpty else {
            completion(.success(true))
            return nil
        }

        let objectManager = BeamObjectManager()

        return try objectManager.saveToAPI(beamObjects) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Could not save all \(passwords.count) passwords: \(error.localizedDescription)",
                                       category: .documentNetwork)
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
    internal func saveOnBeamObjectsAPISuccess(_ updateBeamObjects: [BeamObject],
                                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws {
        Logger.shared.logDebug("Saved \(updateBeamObjects.count) objects on the BeamObject API",
                               category: .documentNetwork)

        let passwordsDB = try PasswordsDB(path: Self.passwordsDBPath)
        var passwords: [PasswordRecord] = []
        for updateBeamObject in updateBeamObjects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var password = try? passwordsDB.fetchWithId(updateBeamObject.id) else {
                completion(.failure(PasswordManagerError.localDocumentNotFound))
                return
            }

            password.previousChecksum = updateBeamObject.dataChecksum
            passwords.append(password)
        }
        try passwordsDB.save(passwords: passwords)
        completion(.success(true))
    }
}
