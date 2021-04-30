//
//  AppDelegate+NSMenu.swift
//  Beam
//
//  Created by Remi Santos on 18/03/2021.
//

import Foundation

private enum MenuEnablingConditionTag: Int {
    // state mode conditions
    case today = 1 // enable only for today mode
    case note = 2 // enable only for node mode
    case web = 4 // enable only for web mode
    case page = 8 // enable only for page mode
    // use binary mask to combine modes

    // other conditions
    case hasBrowserTab = 1001 // enable only if browser tabs are open
}
extension AppDelegate: NSMenuDelegate {

    func subscribeToStateChanges(for state: BeamState) {
        state.$mode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMainMenuItems(for: state)
            }
            .store(in: &cancellableScope)
    }

    func updateMainMenuItems(for state: BeamState) {
        if let menu = NSApp.mainMenu {
            for item in menu.items {
                item.submenu?.delegate = self
                updateMenuItems(items: item.submenu?.items ?? [], for: state)
            }
        }
    }

    private func toggleVisibility(_ visible: Bool, ofAlternatesKeyEquivalentsItems items: [NSMenuItem]) {
        for item in items.filter({ $0.tag < 0 }) {
            item.isHidden = !visible
        }
    }

    // menu items with tag == 0 are ALWAYS enabled and visible
    // menu items with tag == conditionTag are only enabled in the corresponding state
    // menu items with tag == -condition are only enabled in the corresponding state. But not visible to the user.
    private func passConditionTag(tag: Int, for state: BeamState) -> Bool {
        let mode = state.mode
        let rawTag = abs(tag)
        let tagEnum = MenuEnablingConditionTag(rawValue: rawTag)
        if rawTag < 10 {
            return rawTag & mode.rawValue != 0
        } else if tagEnum == .hasBrowserTab {
            return state.hasBrowserTabs
        }
        return false
    }

    private func updateMenuItems(items: [NSMenuItem], for state: BeamState) {
        for item in items {
            if item.tag == 0 { continue }

            let value = abs(item.tag)
            item.isEnabled = passConditionTag(tag: value, for: state)
        }
    }

    // MARK: - NSMenu Delegate
    func menuWillOpen(_ menu: NSMenu) {
        toggleVisibility(false, ofAlternatesKeyEquivalentsItems: menu.items)
        updateMenuItems(items: menu.items, for: window.state)
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleVisibility(true, ofAlternatesKeyEquivalentsItems: menu.items)
    }
}
