import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
    func receivedBeamObjects(_ objects: [BeamObjectProtocol]) throws
}

enum BeamObjectManagerError: Error {
    case notSuccess
    case multipleErrors([Error])
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
    func syncAllFromAPI(delete: Bool = true, _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
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

    func saveAllToAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
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
