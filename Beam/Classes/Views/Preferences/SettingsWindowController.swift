//
//  SettingsWindowController.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 25/07/2022.
//

import Cocoa
import BeamCore

class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private static let toolbarIdentifier = "SettingsWindow-Toolbar"
    var settingsController: SettingsController?
    var settingsTab: [SettingTab]

    var toolbarItemIdentifier: [NSToolbarItem.Identifier] {
        settingsTab.map({ NSToolbarItem.Identifier($0.label) })
    }

    init(settingsTab: [SettingTab]) {
        precondition(!settingsTab.isEmpty, "You need to set at least one SettingTab")

        self.settingsTab = settingsTab

        let settingsController = SettingsController()
        settingsController.configure(settingsTab: self.settingsTab)

        let window = NSWindow(contentViewController: settingsController)
        window.titleVisibility = .visible
        window.styleMask = [.titled, .closable]
        window.backingType = .buffered
        super.init(window: window)

        guard let firstLabel = settingsTab.first?.label else { return }

        let toolbar = NSToolbar(identifier: SettingsWindowController.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.showsBaselineSeparator = true
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: firstLabel)

        window.toolbarStyle = .preference
        window.toolbar = toolbar
        self.settingsController = settingsController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(tab: SettingTab? = nil) {
        if !isWindowLoaded {
            window?.center()
        }
        showWindow(self)

        if let tab = tab {
            select(item: NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: tab.label)))
        } else {
            window?.title = loc(settingsController?.selectedTab?.label ?? "", comment: "Preferences Window Title")
        }
    }

    func select(item: NSToolbarItem) {
        self.settingsController?.selectItem(item.itemIdentifier.rawValue)
        window?.toolbar?.selectedItemIdentifier = item.itemIdentifier
    }

    @objc func selectItem(_ sender: Any?) {
        guard let item = sender as? NSToolbarItem else { return }
        select(item: item)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingTab.settingTab(for: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = itemIdentifier.rawValue
        item.image = NSImage(named: tab.imageName)!
        item.target = self
        item.action = #selector(selectItem(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarItemIdentifier
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarItemIdentifier
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarItemIdentifier
    }
}
