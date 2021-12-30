//
//  AppDelegate+BrowserHistoryImport.swift
//  Beam
//
//  Created by Frank Lefebvre on 05/11/2021.
//

import Foundation
import Cocoa
import BeamCore
import Combine

extension AppDelegate {
    @IBAction func importSafariHistory(_ sender: Any) {
        let importer = SafariImporter()
        importHistory(using: importer)
    }

    @IBAction func importFirefoxHistory(_ sender: Any) {
        let importer = FirefoxImporter()
        importHistory(using: importer)
    }

    @IBAction func importChromeHistory(_ sender: Any) {
        let importer = ChromiumHistoryImporter(browser: .chrome)
        importHistory(using: importer)
    }

    private func importHistory(using importer: BrowserHistoryImporter) {
        data.importsManager.startBrowserHistoryImport(from: importer)
    }
}
