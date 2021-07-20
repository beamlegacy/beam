import Foundation
import BeamCore

// swiftlint:disable file_length
protocol BeamObjectManagerDelegateProtocol {
    // The string used to store beam object types
    static var typeName: String { get }

    // When new beam objects have been received and should be locally stored
    func receivedBeamObjects(_ objects: [BeamObject]) throws

    // Mandatory for using dynamic creation of managers. See `setup` and `parseFilteredObjects`
    init(_ manager: BeamObjectManager)

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject`
    // it will call this method
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?

    // Called within `DocumentManager` to store this object as `BeamObject`
    func saveOnBeamObjectAPI(_ object: BeamObjectProtocol,
                             _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
    // Called within `DocumentManager` to store those objects as `BeamObject`
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectProtocol],
                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
}

class BeamObjectManagerDelegate {
    func structsAsBeamObjects<T: BeamObjectProtocol>(_ structs: [T]) throws -> [BeamObject] {
        try structs.compactMap {
            let object = try BeamObject($0, T.beamObjectTypeName)

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
    case beamObjectInvalidChecksum(BeamObject)
    case beamObjectDecodingError
    case beamObjectEncodingError
}

enum BeamObjectManagerObjectError<T: BeamObjectProtocol>: Error {
    case beamObjectInvalidChecksum(T)
}

extension BeamObjectManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSuccess:
            return "Not Success"
        case .notAuthenticated:
            return "Not Authenticated"
        case .multipleErrors(let errors):
            return "Multiple errors: \(errors)"
        case .beamObjectInvalidChecksum(let object):
            return "Invalid Checksum \(object.id)"
        case .beamObjectDecodingError:
            return "Decoding Error"
        case .beamObjectEncodingError:
            return "Encoding Error"
        }
    }
}

enum BeamObjectConflictResolution {
    // Will overwrite remote object with values from local ones
    case replace

    // Will fetch the remote object, and call the completion with an error and the remote object
    // so the caller can manage conflicts
    case fetchRemoteAndError
}

class BeamObjectManager {
    static var managers: [String: BeamObjectManagerDelegateProtocol.Type] = [:]
    private static var networkRequests: [UUID: APIRequest] = [:]

    static func register<T: BeamObjectManagerDelegateProtocol>(_ manager: T.Type) {
        managers[T.typeName] = manager
    }

    static func setup() {
        // Add any manager using BeamObjects here
        register(DocumentManager.self)
        register(DatabaseManager.self)
        register(PasswordManager.self)
    }

    func clearNetworkCalls() {
        for (_, request) in Self.networkRequests {
            request.cancel()
        }
    }

    var conflictPolicyForSave: BeamObjectConflictResolution = .replace

    internal func parseObjects(_ beamObjects: [BeamObject]) -> Bool {
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

        let filteredObjects: [String: [BeamObject]] = beamObjects.reduce(into: [:]) { result, object in
            result[object.beamObjectType] = result[object.beamObjectType] ?? []
            result[object.beamObjectType]?.append(object)
        }

        parseFilteredObjects(filteredObjects)

//        dump(filteredObjects)

        return true
    }

    internal func parseFilteredObjects(_ filteredObjects: [String: [BeamObject]]) {
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
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()
        let beamObjects = try objects.map {
            try BeamObject($0, T.beamObjectTypeName)
        }
        return try request.saveAll(beamObjects) { result in
            switch result {
            case .failure(let error):
                self.saveToAPIBeamObjectsFailure(objects, error, completion)
            case .success:
                // Not: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving. We only return Bool.

                completion(.success(true))
            }
        }
    }

    func saveToAPI(_ beamObjects: [BeamObject],
                   _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        return try request.saveAll(beamObjects) { result in
            switch result {
            case .failure(let error):
                self.saveToAPIBeamObjectsFailure(beamObjects, error, completion)
            case .success(let updateBeamObjects):
                completion(.success(updateBeamObjects))
            }
        }
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIBeamObjectsFailure<T: BeamObjectProtocol>(_ beamObjects: [T],
                                                                     _ error: Error,
                                                                     _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        Logger.shared.logError("Could not save \(beamObjects): \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            // APIRequestError.beamObjectInvalidChecksum only has 1 object
            guard let beamObject = beamObjects.first else {
                completion(.failure(error))
                return
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let beamObject):
                    do {
                        _ = try self.saveToAPI([beamObject], completion)
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
            return
        case APIRequestError.apiErrors(let errorable):
            guard let errors = errorable.errors else { break }

            Logger.shared.logError("\(errorable)", category: .beamObject)
            do {
                try saveToAPIFailureAPIErrors(beamObjects, errors, completion)
            } catch {
                completion(.failure(error))
            }
            return
        default:
            break
        }

        completion(.failure(error))
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              _ error: Error,
                                              _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) {
        Logger.shared.logError("Could not save \(beamObjects): \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            // APIRequestError.beamObjectInvalidChecksum only has 1 object
            guard let beamObject = beamObjects.first else {
                completion(.failure(error))
                return
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let beamObject):
                    do {
                        _ = try self.saveToAPI([beamObject], completion)
                    } catch {
                        completion(.failure(error))
                    }
                }
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIFailureAPIErrors<T: BeamObjectProtocol>(_ objects: [T],
                                                                   _ errors: [UserErrorData],
                                                                   _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws {
        // We have multiple errors, we're going to fetch each beamObject on the server side to include them in
        // the error we'll return to the object calling this manager
        let group = DispatchGroup()

        var resultErrors: [Error] = []
        var newBeamObjects: [T] = []
        let lock = DispatchSemaphore(value: 1)

        for error in errors {
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let object = objects.first(where: { $0.beamObjectId.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                continue
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard isErrorInvalidChecksum(error) else { continue }

            group.enter()

            fetchAndReturnErrorBasedOnConflictPolicy(object) { result in
                lock.wait()

                switch result {
                case .failure(let error):
                    resultErrors.append(error)
                case .success(let beamObject):
                    newBeamObjects.append(beamObject)
                }

                lock.signal()
                group.leave()
            }
        }

        group.wait()

        if !newBeamObjects.isEmpty && conflictPolicyForSave == .fetchRemoteAndError ||
            !resultErrors.isEmpty && conflictPolicyForSave == .replace {
            fatalError("Should never happen")
        }

        switch conflictPolicyForSave {
        case .replace:
            do {
                _ = try saveToAPI(newBeamObjects, completion)
            } catch {
                completion(.failure(error))
            }
        case .fetchRemoteAndError:

            completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func saveToAPIFailureAPIErrors(_ beamObjects: [BeamObject],
                                            _ errors: [UserErrorData],
                                            _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) {
        // We have multiple errors, we're going to fetch each beamObject on the server side to include them in
        // the error we'll return to the object calling this manager
        let group = DispatchGroup()

        var resultErrors: [Error] = []
        var newBeamObjects: [BeamObject] = []
        let lock = DispatchSemaphore(value: 1)

        for error in errors {
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                continue
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard isErrorInvalidChecksum(error) else { continue }

            group.enter()

            fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                switch result {
                case .failure(let error):
                    lock.wait()
                    resultErrors.append(error)
                    lock.signal()
                case .success(let beamObject):
                    lock.wait()
                    newBeamObjects.append(beamObject)
                    lock.signal()
                }
                group.leave()
            }
        }

        group.wait()

        if !newBeamObjects.isEmpty, conflictPolicyForSave == .fetchRemoteAndError {
            fatalError("Should never happen")
        }

        if !resultErrors.isEmpty, conflictPolicyForSave == .replace {
            fatalError("Should never happen")
        }

        switch conflictPolicyForSave {
        case .replace:
            guard resultErrors.isEmpty else {
                fatalError("Should never happen")
            }
            do {
                _ = try saveToAPI(newBeamObjects, completion)
            } catch {
                completion(.failure(error))
            }
        case .fetchRemoteAndError:
            guard newBeamObjects.isEmpty else {
                fatalError("Should never happen")
            }
            completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
        }
    }

    internal func isErrorInvalidChecksum(_ error: UserErrorData) -> Bool {
        error.message == "Differs from current checksum" && error.path == ["attributes", "previous_checksum"]
    }

    func saveToAPI<T: BeamObjectProtocol>(_ object: T,
                                          _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamObject = try BeamObject(object, T.beamObjectTypeName)

        Self.networkRequests[beamObject.id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[beamObject.id] = request

        return try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success:
                // Not: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving. We only return Bool.
                completion(.success(true))
            case .failure(let error):
                Logger.shared.logError("Could not save \(beamObject): \(error.localizedDescription)",
                                       category: .beamObjectNetwork)

                // Early return except for checksum issues.
                guard case APIRequestError.beamObjectInvalidChecksum = error else {
                    completion(.failure(error))
                    return
                }

                Logger.shared.logError("Invalid Checksum. Local previous checksum: \(beamObject.previousChecksum ?? "-")",
                                       category: .beamObjectNetwork)

                self.fetchAndReturnErrorBasedOnConflictPolicy(object) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let remoteObject):
                        do {
                            Logger.shared.logError("Remote object checksum: \(remoteObject.checksum ?? "-")",
                                                   category: .beamObjectNetwork)
                            Logger.shared.logError("Overwriting local object with remote checksum",
                                                   category: .beamObjectNetwork)

                            _ = try self.saveToAPI(remoteObject, completion)
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    func saveToAPI(_ beamObject: BeamObject,
                   _ completion: @escaping ((Swift.Result<BeamObject, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[beamObject.id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[beamObject.id] = request

        return try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success(let updateBeamObject):
                completion(.success(updateBeamObject))
            case .failure(let error):
                Logger.shared.logError("Could not save \(beamObject): \(error.localizedDescription)",
                                       category: .beamObjectNetwork)

                // Early return except for checksum issues.
                guard case APIRequestError.beamObjectInvalidChecksum = error else {
                    completion(.failure(error))
                    return
                }

                Logger.shared.logError("Invalid Checksum. Local previous checksum: \(beamObject.previousChecksum ?? "-")",
                                       category: .beamObjectNetwork)

                self.fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                    switch result {
                    case .failure: completion(result)
                    case .success(let newBeamObject):
                        do {
                            Logger.shared.logError("Remote object checksum: \(newBeamObject.dataChecksum ?? "-")",
                                                   category: .beamObjectNetwork)
                            Logger.shared.logError("Overwriting local object with remote checksum",
                                                   category: .beamObjectNetwork)

                            _ = try self.saveToAPI(newBeamObject, completion)
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy<T: BeamObjectProtocol>(_ object: T,
                                                                                  _ completion: @escaping (Result<T, Error>) -> Void) {

        guard let beamObject = try? BeamObject(object, T.beamObjectTypeName) else {
            completion(.failure(BeamObjectManagerError.beamObjectEncodingError))
            return
        }

        fetchObject(beamObject) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                switch self.conflictPolicyForSave {
                case .replace:
                    let newBeamObject = beamObject.copy()
                    newBeamObject.previousChecksum = remoteBeamObject.dataChecksum

                    do {
                        var newObject: T = try newBeamObject.decodeBeamObject()
                        newObject.previousChecksum = remoteBeamObject.dataChecksum
                        completion(.success(newObject))
                    } catch {
                        completion(.failure(BeamObjectManagerError.beamObjectDecodingError))
                    }
                case .fetchRemoteAndError:
                    do {
                        var decodedObject: T = try remoteBeamObject.decodeBeamObject()
                        decodedObject.previousChecksum = remoteBeamObject.dataChecksum
                        completion(.failure(BeamObjectManagerObjectError<T>.beamObjectInvalidChecksum(decodedObject)))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject,
                                                           _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        fetchObject(beamObject) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                switch self.conflictPolicyForSave {
                case .replace:
                    let newBeamObject = beamObject.copy()
                    newBeamObject.previousChecksum = remoteBeamObject.dataChecksum
                    completion(.success(newBeamObject))
                case .fetchRemoteAndError:
                    completion(.failure(BeamObjectManagerError.beamObjectInvalidChecksum(remoteBeamObject)))
                }
            }
        }
    }

    internal func fetchObject(_ beamObject: BeamObject,
                              _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        let fetchRequest = BeamObjectRequest()
        do {
            try fetchRequest.fetch(beamObject.id) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let beamObject):
                    completion(.success(beamObject))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func delete(_ id: UUID, _ completion: ((Swift.Result<BeamObject, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[id] = request

        do {
            try request.delete(id) { result in
                switch result {
                case .failure(let error): completion?(.failure(error))
                case .success(let object): completion?(.success(object))
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    func syncAllFromAPI(delete: Bool = true, _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        try fetchAllFromAPI { result in
            switch result {
            case .failure:
                completion?(result)
            case .success(let success):
                guard success == true else {
                    completion?(result)
                    return
                }

                do {
                    try self.saveAllToAPI()
                    completion?(.success(true))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func saveAllToAPI() throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)
        var dataTasks: [URLSessionTask] = []

        for (_, managerClass) in Self.managers {
            group.enter()

            let manager = managerClass.init(self)

            Logger.shared.logDebug("saveAllOnBeamObjectApi using \(manager)",
                                   category: .beamObjectNetwork)
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
            throw BeamObjectManagerError.multipleErrors(errors)
        }
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
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
    }
}

// swiftlint:enable file_length
