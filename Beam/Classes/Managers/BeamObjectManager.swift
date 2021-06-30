import Foundation
import BeamCore

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

        for (key, objects) in filteredObjects {
            switch key {
            case .document:
                let documentObjects: [DocumentStruct] = objects.compactMap { $0.decode() }
                do {
                    try DocumentManager().receivedBeamObjects(documentObjects)
                } catch {
                    Logger.shared.logError("Error with documents: \(error)", category: .beamObjectNetwork)
                }
            case .database:
                let databaseObjects: [DatabaseStruct] = objects.compactMap { $0.decode() }
                do {
                    try DatabaseManager().receivedBeamObjects(databaseObjects)
                } catch {
                    Logger.shared.logError("Error with databases: \(error)", category: .beamObjectNetwork)
                }
            case .password:
                Logger.shared.logError("Password not yet managed: \(key)", category: .beamObjectNetwork)
            }
        }

//        dump(filteredObjects)

        return true
    }
}

// MARK: - Foundation
extension BeamObjectManager {
    func fetchAllFromAPI(delete: Bool = true, _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let beamRequest = BeamObjectRequest()

        let lastUpdatedAt = Persistence.Sync.BeamObjects.updated_at
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
