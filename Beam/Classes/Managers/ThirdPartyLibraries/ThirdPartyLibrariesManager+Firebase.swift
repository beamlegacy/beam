//
//  ThirdPartyLibrariesManager+Firebase.swift
//  Beam
//
//  Created by Remi Santos on 23/01/2022.
//

import Foundation
import Firebase
import BeamCore

extension ThirdPartyLibrariesManager {

    private func shouldUpdateConfigFile(atPath: String, fileManager: FileManager) -> Bool {
        guard fileManager.fileExists(atPath: atPath), let dictionary = NSDictionary(contentsOfFile: atPath) else {
            Logger.shared.logDebug("Firebase options file not found on disk", category: .tracking)
            return true
        }
        if NSDictionary(dictionary: Configuration.Firebase.plistDictionary) != dictionary {
            Logger.shared.logDebug("New Firebase options detected", category: .tracking)
            return true
        }
        Logger.shared.logDebug("Firebase options file detected", category: .tracking)
        return false
    }

    private func getFirebaseConfigFilePath() -> String? {
        let fileManager = FileManager.default
        guard let documentDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            Logger.shared.logError("Couldn't build path for Firebase file directory", category: .tracking)
            return nil
        }
        let path = documentDirectory.appending("/GoogleService-Info.plist")
        let envConfigDictionary = Configuration.Firebase.plistDictionary
        if shouldUpdateConfigFile(atPath: path, fileManager: fileManager) {
            let someData = NSDictionary(dictionary: envConfigDictionary)
            let success = someData.write(toFile: path, atomically: true)
            Logger.shared.logDebug("Firebase options saved to disk (succesful: \(success))", category: .tracking)
        }
        let usedProjectId = envConfigDictionary["PROJECT_ID"] as? String
        if usedProjectId == EnvironmentVariables.Firebase.projectID {
            Logger.shared.logInfo("Firebase setup using release configuration", category: .tracking)
        } else if usedProjectId == EnvironmentVariables.Firebase.projectIDDev {
            Logger.shared.logDebug("Firebase setup using dev configuration", category: .tracking)
        } else {
            Logger.shared.logDebug("Firebase setup is incorrect", category: .tracking)
        }
        return path
    }

    func setupFirebase() {
        // Because we're using a custom configuration, you might see the following warning in the logs
        //      "Analytics requires Google App ID from GoogleService-Info.plist. Your data may be lost."
        // This is an intended warning, but should still behave as expected,
        // see https://github.com/firebase/quickstart-ios/issues/75#issuecomment-312556370
        // Use -FIRAnalyticsDebugEnabled scheme argument to see changes in debug view.

        guard Configuration.env != .test else {
            // Disabling Firebase for tests build because it would require another setup (different bundle id)
            return
        }
        guard Configuration.env != .debug || !Configuration.Firebase.clientID.hasPrefix("$(") else {
            // In debug, we allow no firebase config.
            Logger.shared.logDebug("Firebase Analytics not enabled", category: .tracking)
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let filePath = self?.getFirebaseConfigFilePath(),
                  let fileopts = FirebaseOptions(contentsOfFile: filePath) else {
                    assert(false, "Firebase config file couldn't load")
                      return
                  }
            DispatchQueue.main.async {
                FirebaseApp.configure(options: fileopts)
                Logger.shared.logDebug("Firebase Analytics enabled", category: .tracking)
            }
        }
    }

    func setFirebaseUser() {
        // nothing here yet.
    }
}
