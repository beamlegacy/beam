import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
    func receivedBeamObjects(_ objects: [BeamObjectProtocol]) throws
    func saveOnBeamObjectAPI(_ object: BeamObjectProtocol,
                             _ forced: Bool,
                             _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectProtocol],
                              _ forced: Bool,
                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
}

enum BeamObjectManagerError: Error {
    case notSuccess
    case notAuthenticated
    case multipleErrors([Error])
    case beamObjectInvalidChecksum(BeamObjectProtocol)
    case beamObjectDecodingError
}

public class BeamObjectManager {
    internal func parseObjects(_ beamObjects: [BeamObjectAPIType]) -> Bool {
        let lastUpdatedAt = Persistence.Sync.BeamObjects.updated_at

        // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
        // If not doing a delta sync, we don't as we want to update local document as `deleted`
        if lastUpdatedAt != nil && beamObjects.isEmpty {
            Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
            return true
        }

        if let mostRecentUpdatedAt = beamObjects.compactMap({ $0.updatedAt }).sorted().last {
            Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(beamObjects.count) beam objects fetched.",
                                   category: .beamObjectNetwork)
        }

        let filteredObjects: [BeamObjectType: [BeamObjectAPIType]] = beamObjects.reduce(into: [:]) { result, object in
            guard let beamObjectType = object.beamObjectType else { return }
            result[beamObjectType] = result[beamObjectType] ?? []

            result[beamObjectType]?.append(object)
        }

        parseFilteredObjects(filteredObjects)

//        dump(filteredObjects)

        return true
    }

    internal func parseFilteredObjects(_ filteredObjects: [BeamObjectType: [BeamObjectAPIType]]) {
        let documentManager = DocumentManager()
        let databaseManager = DatabaseManager()

        for (key, objects) in filteredObjects {
            switch key {
            case .document:
                let documentObjects: [DocumentStruct] = objects.compactMap { $0.decode() }
                guard !documentObjects.isEmpty else { continue }

                do {
                    try documentManager.receivedBeamObjects(documentObjects)
                } catch {
                    Logger.shared.logError("Error with documents: \(error)", category: .beamObjectNetwork)
                }
            case .database:
                let databaseObjects: [DatabaseStruct] = objects.compactMap { $0.decode() }
                guard !databaseObjects.isEmpty else { continue }
                do {
                    try databaseManager.receivedBeamObjects(databaseObjects)
                } catch {
                    Logger.shared.logError("Error with databases: \(error)", category: .beamObjectNetwork)
                }
            case .password:
                Logger.shared.logError("Password not yet managed: \(key)", category: .beamObjectNetwork)
            }
        }
    }
}

// MARK: - Foundation
extension BeamObjectManager {
    func saveToAPI(_ beamObjects: [BeamObjectAPIType],
                   _ completion: @escaping ((Swift.Result<[BeamObjectAPIType], Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion(.failure(BeamObjectManagerError.notAuthenticated))
            return nil
        }

        let request = BeamObjectRequest()

        return try request.saveAll(beamObjects) { result in
            switch result {
            case .failure(let error):
                self.saveToAPIFailure(beamObjects, error, completion)
            case .success(let updateBeamObject):
                completion(.success(updateBeamObject))
            }
        }
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIFailure(_ beamObjects: [BeamObjectAPIType],
                                   _ error: Error,
                                   _ completion: @escaping ((Swift.Result<[BeamObjectAPIType], Error>) -> Void)) {
        Logger.shared.logError("Could not save \(beamObjects): \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            // We only have 1 item for such error
            guard let beamObject = beamObjects.first else {
                completion(.failure(error))
                return
            }

            saveToAPIFailure(beamObject) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success:
                    // This is never called by `saveToAPIFailure`
                    break
                }
            }
            return
        case APIRequestError.apiErrors(let errorable):
            Logger.shared.logError("\(errorable)", category: .beamObject)

            guard let errors = errorable.errors else { break }

            // We have multiple errors, we're going to fetch each beamObject on the server side to include them in
            // the error we'll return to the object calling this manager
            let group = DispatchGroup()

            var resultErrors: [Error] = []
            let lock = DispatchSemaphore(value: 1)

            for error in errors {
                // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
                guard let beamObject = beamObjects.first(where: { $0.id == error.objectid }) else {
                    continue
                }

                // We only call `saveToAPIFailure` with invalid checksum errors
                guard isErrorInvalidChecksum(error) else { continue }

                group.enter()
                saveToAPIFailure(beamObject) { result in
                    defer { group.leave() }

                    switch result {
                    case .failure(let error):
                        lock.wait()
                        resultErrors.append(error)
                        lock.signal()
                    case .success:
                        // This is never called by `saveToAPIFailure`
                        break
                    }
                }
            }

            group.wait()
            completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
            return
        default:
            break
        }

        completion(.failure(error))
    }

    internal func isErrorInvalidChecksum(_ error: UserErrorData) -> Bool {
        error.message == "Differs from current checksum" && error.path == ["attributes", "previous_checksum"]
    }

    func saveToAPI(_ beamObject: BeamObjectAPIType,
                   _ completion: @escaping ((Swift.Result<BeamObjectAPIType, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion(.failure(BeamObjectManagerError.notAuthenticated))
            return nil
        }

        let request = BeamObjectRequest()

        return try request.save(beamObject) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Could not save \(beamObject): \(error.localizedDescription)", category: .beamObject)

                // Early return except for checksum issues.
                guard case APIRequestError.beamObjectInvalidChecksum = error else {
                    completion(.failure(error))
                    return
                }

                self.saveToAPIFailure(beamObject, completion)
            case .success(let updateBeamObject):
                completion(.success(updateBeamObject))
            }
        }
    }

    /// In case of checksum issue, this will fetch the object on the API side to include remote side object + local object when returning the error to the caller
    /// Only the `.failure` part of the result is used, but we don't change it so this can be used passing the completion handler as it is
    internal func saveToAPIFailure(_ beamObject: BeamObjectAPIType,
                                   _ completion: @escaping ((Swift.Result<BeamObjectAPIType, Error>) -> Void)) {

        /*
         When we have checksum issues, we fetch the current API saved object so the caller have both and is
         able to merge them if needed
         */
        let fetchRequest = BeamObjectRequest()
        do {
            try fetchRequest.fetch(beamObject.id) { result in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let beamObject):
                    guard let type = beamObject.beamObjectType else {
                        completion(.failure(BeamObjectManagerError.beamObjectDecodingError))
                        return
                    }

                    switch type {
                    case .document:
                        if let document: DocumentStruct = beamObject.decode() {
                            completion(.failure(BeamObjectManagerError.beamObjectInvalidChecksum(document)))
                            return
                        }
                    case .database:
                        if let database: DatabaseStruct = beamObject.decode() {
                            completion(.failure(BeamObjectManagerError.beamObjectInvalidChecksum(database)))
                            return
                        }
                    case .password:
                        break
                    }

                    completion(.failure(BeamObjectManagerError.beamObjectDecodingError))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func syncAllFromAPI(delete: Bool = true, _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        fetchAllFromAPI { result in
            switch result {
            case .failure:
                completion?(result)
            case .success(let success):
                guard success == true else {
                    completion?(result)
                    return
                }

                // Must call in another dispatchqueue or it fails, not sure why...
                DispatchQueue.main.async {
                    self.saveAllToAPI(completion)
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func saveAllToAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let managers: [BeamObjectManagerDelegateProtocol] = [DatabaseManager(), DocumentManager()]
        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)
        var dataTasks: [URLSessionTask] = []

        for manager in managers {
            group.enter()

            do {
                let task = try manager.saveAllOnBeamObjectApi { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                        lock.wait()
                        errors.append(error)
                        lock.signal()
                    case .success(let success):
                        guard success == true else {
                            lock.wait()
                            errors.append(BeamObjectManagerError.notSuccess)
                            lock.signal()
                            return
                        }
                    }

                    group.leave()
                }

                if let task = task {
                    dataTasks.append(task)
                }
            } catch {
                lock.wait()
                errors.append(BeamObjectManagerError.notSuccess)
                lock.signal()
                group.leave()
            }
        }

        Logger.shared.logDebug("saveAllOnBeamObjectApi waiting",
                               category: .beamObjectNetwork)
        group.wait()

        Logger.shared.logDebug("saveAllOnBeamObjectApi waited",
                               category: .beamObjectNetwork)

        guard errors.isEmpty else {
            completion?(.failure(BeamObjectManagerError.multipleErrors(errors)))
            return
        }

        completion?(.success(true))
    }

    /// Will fetch all updates from the API
    /// - Parameters:
    ///   - completion: <#completion description#>
    func fetchAllFromAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let beamRequest = BeamObjectRequest()

        let lastUpdatedAt: Date? = Persistence.Sync.BeamObjects.updated_at
        let timeNow = BeamDate.now

        if let lastUpdatedAt = lastUpdatedAt {
            Logger.shared.logDebug("Using updatedAt for BeamObjects API call: \(lastUpdatedAt)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        do {
            try beamRequest.fetchAll(lastUpdatedAt) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logDebug("fetchAllFromAPI: \(error.localizedDescription)",
                                           category: .beamObjectNetwork)
                    completion?(.failure(error))
                case .success(let beamObjects):
                    let success = self.parseObjects(beamObjects)
                    if success {
                        Persistence.Sync.BeamObjects.updated_at = timeNow
                    }
                    completion?(.success(success))
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }
}
