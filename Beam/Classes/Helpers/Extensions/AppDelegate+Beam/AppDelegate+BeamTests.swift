//
//  AppDelegate+BeamTests.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 12/02/2021.
//

import Foundation

extension AppDelegate {
    #if DEBUG
    func prepareMenuForTestEnv() {
        let prepareBeam = NSMenuItem()
        prepareBeam.submenu = NSMenu(title: "Prepare Beam")
        let eraseDBMenu = NSMenuItem(title: "Destroy DB", action: #selector(destroyDatabase(sender:)), keyEquivalent: "")
        let populateDBMenu = NSMenuItem(title: "Populate DB", action: #selector(populateDatabase(sender:)), keyEquivalent: "")
        prepareBeam.submenu?.items = [
            populateDBMenu, eraseDBMenu
        ]
        NSApp.mainMenu?.addItem(prepareBeam)
    }

    @IBAction @objc func destroyDatabase(sender: NSMenuItem) {
        self.beamUIHelper?.destroyDatabase()
    }

    @IBAction @objc func populateDatabase(sender: NSMenuItem) {
        self.beamUIHelper?.populateWithJournalNote(count: 100)
    }
    #endif
}
