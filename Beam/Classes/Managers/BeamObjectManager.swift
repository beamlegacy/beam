import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    // The string used to store beam object types
    static var typeName: String { get }

    // When new objects have been received through the syncAll
    func receivedBeamObjects(_ objects: [BeamObjectAPIType]) throws

    // Mandatory for using dynamic creation of managers. See `setup` and `parseFilteredObjects`
    init(_ manager: BeamObjectManager)

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject` it will call this method
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?

    // Called within `DocumentManager` to store this object as `BeamObject`
    func saveOnBeamObjectAPI(_ object: BeamObjectProtocol,
                             _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
    // Called within `DocumentManager` to store those objects as `BeamObject`
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectProtocol],
                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
}

class BeamObjectManagerDelegate {
    func structsAsBeamObjects<T: BeamObjectProtocol>(_ structs: [T]) throws -> [BeamObjectAPIType] {
        try structs.compactMap {
            let object = try BeamObjectAPIType($0, T.beamObjectTypeName)

            // We don't want to send updates for documents already sent.
            // We know it's sent because the previousChecksum is the same as the current data Checksum
            guard object.previousChecksum != object.dataChecksum, object.dataChecksum != nil else {
                return nil
            }

            return object
        }
    }
}

enum BeamObjectManagerError: Error {
    case notSuccess
    case notAuthenticated
    case multipleErrors([Error])
    case beamObjectInvalidChecksum(BeamObjectAPIType)
    case beamObjectDecodingError
}

class BeamObjectManager {
    static var managers: [String: BeamObjectManagerDelegateProtocol.Type] = [:]

    static func register<T: BeamObjectManagerDelegateProtocol>(_ manager: T.Type) {
        managers[T.typeName] = manager
    }

    static func setup() {
        // Add any manager using BeamObjects here
        register(DocumentManager.self)
        register(DatabaseManager.self)
    }

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

        let filteredObjects: [String: [BeamObjectAPIType]] = beamObjects.reduce(into: [:]) { result, object in
            result[object.beamObjectType] = result[object.beamObjectType] ?? []
            result[object.beamObjectType]?.append(object)
        }

        parseFilteredObjects(filteredObjects)

//        dump(filteredObjects)

        return true
    }

    internal func parseFilteredObjects(_ filteredObjects: [String: [BeamObjectAPIType]]) {
        var initiatedManagers: [String: BeamObjectManagerDelegateProtocol] = [:]

        for (key, objects) in filteredObjects {
            guard let manager = Self.managers[key] else {
                Logger.shared.logError("**manager for \(key) not found**", category: .beamObjectNetwork)
                continue
            }

            initiatedManagers[key] = initiatedManagers[key] ?? manager.init(self)

            do {
                try initiatedManagers[key]?.receivedBeamObjects(objects)
            } catch {
                Logger.shared.logError("Error with objects: \(error)", category: .beamObjectNetwork)
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
            guard let beamObject = beamObjects.first else {
                completion(.failure(error))
                return
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            saveToAPIFailure(beamObject) { error in
                completion(.failure(error))
            }
            return
        case APIRequestError.apiErrors(let errorable):
            guard let errors = errorable.errors else { break }

            Logger.shared.logError("\(errorable)", category: .beamObject)
            saveToAPIFailureAPIErrors(beamObjects, errors, completion)
            return
        default:
            break
        }

        completion(.failure(error))
    }

    internal func saveToAPIFailureAPIErrors(_ beamObjects: [BeamObjectAPIType],
                                            _ errors: [UserErrorData],
                                            _ completion: @escaping ((Swift.Result<[BeamObjectAPIType], Error>) -> Void)) {
        // We have multiple errors, we're going to fetch each beamObject on the server side to include them in
        // the error we'll return to the object calling this manager
        let group = DispatchGroup()

        var resultErrors: [Error] = []
        let lock = DispatchSemaphore(value: 1)

        for error in errors {
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                continue
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard isErrorInvalidChecksum(error) else { continue }

            group.enter()

            self.saveToAPIFailure(beamObject) { error in
                lock.wait()
                resultErrors.append(error)
                lock.signal()

                group.leave()
            }
        }

        group.wait()
        completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
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

                self.saveToAPIFailure(beamObject) {
                    completion(.failure($0))
                }
            case .success(let updateBeamObject):
                completion(.success(updateBeamObject))
            }
        }
    }

    /// In case of checksum issue, this will fetch the object on the API side to include remote side object + local object when returning the error to the caller
    /// Only the `.failure` part of the result is used, but we don't change it so this can be used passing the completion handler as it is
    internal func saveToAPIFailure(_ beamObject: BeamObjectAPIType,
                                   _ completion: @escaping (Error) -> Void) {

        /*
         When we have checksum issues, we fetch the current API saved object so the caller have both and is
         able to merge them if needed
         */
        let fetchRequest = BeamObjectRequest()
        do {
            try fetchRequest.fetch(beamObject.id.uuidString) { result in
                switch result {
                case .failure(let error): completion(error)
                case .success(let beamObject):
                    completion(BeamObjectManagerError.beamObjectInvalidChecksum(beamObject))
                }
            }
        } catch {
            completion(error)
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
