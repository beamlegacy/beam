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
    case hasTabGroupingWindowPrefOn = 1011
}

extension AppDelegate: NSMenuDelegate, NSMenuItemValidation {

    func subscribeToStateChanges(for state: BeamState) {
        state.$mode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMainMenuItems(for: state)
            }
            .store(in: &cancellableScope)
    }

    func updateMainMenuItems(for state: BeamState?) {
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
    private func passConditionTag(tag: Int, for state: BeamState?) -> Bool {
        let mode: Mode = state?.mode ?? .today
        let rawTag = abs(tag)
        let tagEnum = MenuEnablingConditionTag(rawValue: rawTag)
        if rawTag < 1000 {
            return rawTag & mode.rawValue != 0
        } else if tagEnum == .hasBrowserTab {
            return state?.hasBrowserTabs ?? false
        } else if tagEnum == .hasTabGroupingWindowPrefOn {
            return PreferencesManager.showTabGrougpingMenuItem
        }
        return false
    }

    private func updateMenuItems(items: [NSMenuItem], for state: BeamState?) {
        for item in items {
            if item.tag == 0 { continue }

            let value = abs(item.tag)
            item.isEnabled = passConditionTag(tag: value, for: state)

            if item.action == #selector(BeamWindow.collectPageToCard(_:)) {
                updateFullPageCollectMenu(item)
            }
        }
    }

    private func updateFullPageCollectMenu(_ menuItem: NSMenuItem) {
        guard let currentTab = window?.state.browserTabsManager.currentTab else { return }
        if let note = currentTab.noteController.note {
            menuItem.title = "Collect Page to \(note.title)"
        } else {
            menuItem.title = "Collect Page to Card…"
        }
    }

    // MARK: - NSMenu Delegate
    func menuWillOpen(_ menu: NSMenu) {
        toggleVisibility(false, ofAlternatesKeyEquivalentsItems: menu.items)
        updateMenuItems(items: menu.items, for: window?.state)
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleVisibility(true, ofAlternatesKeyEquivalentsItems: menu.items)
    }

    // MARK: - NSMenuItemValidation Delegate
    // Support for native auto-enable menu items
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.tag != 0 else { return true }
        let value = abs(menuItem.tag)
        if let customValidationItem = menuItem as? MenuItemCustomValidation {
            return customValidationItem.validateForState(window?.state, window: window)
        }
        return passConditionTag(tag: value, for: window?.state)
    }
}

// MARK: - Custom Item Validation
private protocol MenuItemCustomValidation {
    func validateForState(_ state: BeamState?, window: NSWindow?) -> Bool
}

class WebviewRelatedMenuItem: NSMenuItem, MenuItemCustomValidation {
    func validateForState(_ state: BeamState?, window: NSWindow?) -> Bool {
        let textViewFirstResponder = window?.firstResponder as? NSTextView
        let beamTextField = textViewFirstResponder?.delegate as? BeamNSTextFieldProtocol
        return state?.mode == .web &&
            state?.browserTabsManager.currentTab != nil
            && beamTextField == nil
    }
}

class LoadedWebviewRelatedMenuItem: NSMenuItem, MenuItemCustomValidation {
    func validateForState(_ state: BeamState?, window: NSWindow?) -> Bool {
        return state?.mode == .web &&
            state?.browserTabsManager.currentTab != nil
        && state?.browserTabsManager.currentTab?.url != nil
        && !(state?.browserTabsManager.currentTab?.isLoading ?? true)
    }
}
