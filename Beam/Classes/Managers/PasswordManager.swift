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
                self.saveOnBeamObjectAPIFailure(password, error, completion)
            case .success(let updateBeamObject):
                do {
                    try self.saveOnBeamObjectsAPISuccess([updateBeamObject], completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    internal func saveOnBeamObjectAPIFailure(_ password: PasswordRecord,
                                             _ error: Error,
                                             _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        // Early return except for checksum issues.
        guard case BeamObjectManagerError.beamObjectInvalidChecksum(let remoteBeamObject) = error else {
            completion(.failure(error))
            return
        }

        do {
            // Checksum issue, the API side of the object was updated since our last fetch
            let mergedPassword = try manageConflict(password, remoteBeamObject, error)

            _ = try self.saveOnBeamObjectAPI(mergedPassword, completion)
        } catch {
            completion(.failure(error))
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
                self.saveOnBeamObjectsAPIFailure(passwords, error, completion)
            case .success(let updateBeamObjects):
                do {
                    try self.saveOnBeamObjectsAPISuccess(updateBeamObjects, completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

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

    internal func saveOnBeamObjectsAPIFailure(_ passwords: [PasswordRecord],
                                              _ error: Error,
                                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        // This case happens when we use the network call to send multiple documents,
        // but only send 1 and have an invalid checksum
        if case BeamObjectManagerError.beamObjectInvalidChecksum = error,
           let password = passwords.first {
            saveOnBeamObjectAPIFailure(password, error, completion)
            return
        }

        // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
        guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
            completion(.failure(error))
            return
        }

        var newPasswords: [PasswordRecord] = []
        for insideError in errors {
            /*
             We have multiple errors. If all errors are about invalid checksums, we can fix and retry. Else we'll just
             stop and call the completion handler with the original error
             */
            guard case BeamObjectManagerError.beamObjectInvalidChecksum(let remoteBeamObject) = insideError else {
                completion(.failure(error))
                return
            }

            // Here we should try to merge remoteBeamObject converted as a Password, and our local one.
            // For now we just overwrite the API with our local version with a batch call resending all of them
            guard let password = passwords.first(where: { $0.uuid == remoteBeamObject.id }) else {
                Logger.shared.logError("Could not save: \(insideError.localizedDescription)",
                                       category: .passwordNetwork)
                Logger.shared.logError("No ID :( for \(remoteBeamObject.id)", category: .passwordNetwork)
                continue
            }

            do {
                let mergedDPassword = try manageConflict(password, remoteBeamObject, insideError)
                newPasswords.append(mergedDPassword)
            } catch {
                completion(.failure(error))
                return
            }
        }

        do {
            _ = try self.saveOnBeamObjectsAPI(newPasswords, completion)
        } catch {
            completion(.failure(error))
        }
    }

    internal func manageConflict(_ password: PasswordRecord,
                                 _ remoteBeamObject: BeamObject,
                                 _ error: Error) throws -> PasswordRecord {
        let remotePassword: PasswordRecord = try remoteBeamObject.decodeBeamObject()

        Logger.shared.logError("Could not save: \(error.localizedDescription)",
                               category: .passwordNetwork)
        Logger.shared.logError("local object \(password.previousChecksum ?? "-"): \(password)",
                               category: .passwordNetwork)
        Logger.shared.logError("Remote saved object \(remotePassword.checksum ?? "-"): \(remotePassword)",
                               category: .passwordNetwork)
        Logger.shared.logError("Resending local object with remote checksum \(remotePassword.checksum ?? "-")",
                               category: .passwordNetwork)

        // TODO: we should merge `documentStruct` and `remoteBeamObject` instead of just resending the
        // same documentStruct we sent before
        var mergedPassword = password.copy()
        mergedPassword.previousChecksum = remotePassword.checksum
        return mergedPassword
    }
}
