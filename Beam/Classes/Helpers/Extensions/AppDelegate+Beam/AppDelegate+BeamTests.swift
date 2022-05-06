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
        BeamUITestsMenuGenerator.beeper = CrossTargetNotificationCenterBeeper()
        let prepareBeam = NSMenuItem()
        prepareBeam.submenu = NSMenu(title: "UITests")
        var groupMenus: [UITestMenuGroup: NSMenu] = [:]
        UITestMenuAvailableCommands.allCases.forEach { item in
            let value = item.rawValue
            var menuItem: NSMenuItem
            let shortcut = item.shortcut
            if value.hasPrefix("separator") {
                menuItem = NSMenuItem.separator()
            } else {
                BeamUITestsMenuGenerator.beeper?.register(identifier: value) { [unowned self] in
                    beamUIMenuGenerator.executeCommand(item)
                }
                menuItem = NSMenuItem(title: item.rawValue,
                                      action: #selector(menuCalled),
                                      keyEquivalent: shortcut?.key ?? "")
                if let modifiers = shortcut?.modifiers {
                    menuItem.keyEquivalentModifierMask = modifiers
                }
            }
            var parentMenu = prepareBeam.submenu
            if let group = item.group {
                if groupMenus[group] == nil {
                    let subMenu = NSMenu(title: group.rawValue)
                    groupMenus[group] = subMenu
                    let groupItem = NSMenuItem(title: group.rawValue, action: nil, keyEquivalent: "")
                    prepareBeam.submenu?.addItem(groupItem)
                    prepareBeam.submenu?.setSubmenu(subMenu, for: groupItem)
                }
                parentMenu = groupMenus[group]
            }
            parentMenu?.addItem(menuItem)
        }
        NSApp.mainMenu?.addItem(prepareBeam)
    }

    @objc
    func menuCalled(sender: NSMenuItem) {
        UITestMenuAvailableCommands.allCases.forEach {
            if $0.rawValue == sender.title {
                beamUIMenuGenerator.executeCommand($0)
                return
            }
        }
    }
    #endif
}
