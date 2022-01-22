//
//  AppDelegate+BrowserImport.swift
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

    @IBAction func importBraveHistory(_ sender: Any) {
        let importer = ChromiumHistoryImporter(browser: .brave)
        importHistory(using: importer)
    }

    @IBAction func importChromePasswords(_ sender: Any) {
        let importer = ChromiumPasswordImporter(browser: .chrome)
        importPasswords(using: importer)
    }

    @IBAction func importBravePasswords(_ sender: Any) {
        let importer = ChromiumPasswordImporter(browser: .brave)
        importPasswords(using: importer)
    }

    @IBAction func importCSVPasswords(_ sender: Any) {
        openCSVFilePanel { csvFile in
            if let csvFile = csvFile {
                self.importPasswords(from: csvFile)
            }
        }
    }

    private func openCSVFilePanel(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canDownloadUbiquitousContents = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["csv", "txt"]
        openPanel.title = "Select a csv file exported from Firefox or Safari"
        openPanel.begin { result in
            openPanel.close()
            completion(result == .OK ? openPanel.url : nil)
        }
    }

    private func importHistory(using importer: BrowserHistoryImporter) {
        data.importsManager.startBrowserHistoryImport(from: importer)
    }

    private func importPasswords(using importer: BrowserPasswordImporter) {
        data.importsManager.startBrowserPasswordImport(from: importer)
    }

    private func importPasswords(from csvFile: URL) {
        data.importsManager.startBrowserPasswordImport(from: csvFile)
    }
}
