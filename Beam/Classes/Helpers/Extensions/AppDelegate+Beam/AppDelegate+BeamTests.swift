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
        let eraseDBMenu = NSMenuItem(title: "Destroy DB", action: #selector(destroyDbActn(sender:)), keyEquivalent: "")
        let populateDBMenu = NSMenuItem(title: "Populate DB", action: #selector(populateDbActn(sender:)), keyEquivalent: "")
        prepareBeam.submenu?.items = [
            populateDBMenu, eraseDBMenu
        ]
        NSApp.mainMenu?.addItem(prepareBeam)
    }

    @objc func destroyDbActn(sender : NSMenuItem) {
        guard let helper = self.beamHelper else { return }
        helper.destroyDb()
    }

    @objc func populateDbActn(sender : NSMenuItem) {
        guard let helper = self.beamHelper else { return }
        helper.populateWithJournalNote(count: 100)
    }
    #endif
}
