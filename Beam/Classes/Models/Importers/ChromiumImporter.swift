//
//  ChromiumImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 08/02/2022.
//

import Foundation
import BeamCore

class ChromiumImporter {
    private(set) var browser: ChromiumBrowserInfo

    init(browser: ChromiumBrowserInfo) {
        self.browser = browser
    }

    func chromiumDirectory(fileCount: inout SandboxEscape.FileCount) throws -> URL? {
        struct Profile: Decodable {
            var lastUsed: String
        }
        struct LocalState: Decodable {
            var profile: Profile
        }
        let applicationSupportDirectory = SandboxEscape.actualHomeDirectory().appendingPathComponent("Library").appendingPathComponent("Application Support")
        let browserDirectory = applicationSupportDirectory.appendingPathComponent(browser.databaseDirectory)
        do {
            guard let localStateFile = try SandboxEscape.endorsedURL(for: browserDirectory.appendingPathComponent("Local State"), fileCount: &fileCount) else {
                return nil // cancelled by user
            }
            let localStateData = try Data(contentsOf: localStateFile)
            let decoder = BeamJSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let localState = try decoder.decode(LocalState.self, from: localStateData)
            return browserDirectory.appendingPathComponent(localState.profile.lastUsed, isDirectory: true)
        } catch {
            return browserDirectory.appendingPathComponent("Default", isDirectory: true)
        }
    }
}
