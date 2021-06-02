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
        prepareBeam.submenu = NSMenu(title: "UITests")

        MenuAvailableCommands.allCases.forEach { item in
            let value = item.rawValue
            if value.hasPrefix("separator") {
                prepareBeam.submenu?.items.append(NSMenuItem.separator())
            } else {
                prepareBeam.submenu?.items.append(NSMenuItem(title: item.rawValue,
                                                             action: #selector(menuCalled),
                                                             keyEquivalent: ""))
            }
        }

        NSApp.mainMenu?.addItem(prepareBeam)
    }

    @IBAction @objc func menuCalled(sender: NSMenuItem) {
        MenuAvailableCommands.allCases.forEach {
            if $0.rawValue == sender.title {
                beamUIMenuGenerator.executeCommand($0)
                return
            }
        }
    }
    #endif
}
