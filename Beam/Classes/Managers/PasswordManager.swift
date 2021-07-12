import Foundation
import BeamCore

//class PasswordManager {
//    func saveAllOnBeamObjectApi(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
//        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
//            completion?(.success(false))
//            return
//        }
//
//        let passwordDb = try PasswordsDB()
//
//        try passwordDb.dbQueue.read { db in
//            do {
//                let passwords = try PasswordsRecord.fetchAll(db)
//
//                let beamObjects: [BeamObject] = try passwords.map {
//                    // TODO: get the `previousChecksum` and send it
//                    try BeamObject($0, .password)
//                }
//
//                guard !beamObjects.isEmpty else {
//                    completion?(.success(true))
//                    return
//                }
//
//                let request = BeamObjectRequest()
//
//                try request.saveAll(beamObjects) { result in
//                    switch result {
//                    case .failure(let error):
//                        Logger.shared.logError("Could not save all \(beamObjects): \(error.localizedDescription)", category: .beamObject)
//
//                        completion?(.failure(error))
//                    case .success(let updateBeamObject):
//                        Logger.shared.logDebug("Saved \(updateBeamObject)", category: .beamObject)
//
//                        // TODO: store the checksum we sent
//                        completion?(.success(true))
//                    }
//                }
//            } catch {
//                completion?(.failure(error))
//            }
//        }
//    }
//}
