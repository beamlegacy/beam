//
//  AppDelegate+NSMenu.swift
//  Beam
//
//  Created by Remi Santos on 18/03/2021.
//

import Foundation

extension AppDelegate: NSMenuDelegate {

    func subscribeToStateChanges(for state: BeamState) {
        state.$mode.sink { [weak self] mode in
            guard let self = self else { return }
            self.updateMainMenuItems(for: mode)
        }.store(in: &cancellableScope)
    }

    func updateMainMenuItems(for mode: Mode) {
        if let menu = NSApp.mainMenu {
            for item in menu.items {
                item.submenu?.delegate = self
                updateMenuItems(items: item.submenu?.items ?? [], for: mode.rawValue)
            }
        }
    }

    private func toggleVisibility(_ visible: Bool, ofAlternatesKeyEquivalentsItems items: [NSMenuItem]) {
        for item in items.filter({ $0.tag < 0 }) {
            item.isHidden = !visible
        }
    }

    // menu items with tag == 0 are ALWAYS enabled and visible
    // menu items with tag == mode are only enabled in the corresponding mode
    // menu items with tag == -mode are only enabled and visible in the corresponding mode
    private func updateMenuItems(items: [NSMenuItem], for mode: Int) {
        for item in items {
            if item.tag == 0 { continue }

            let value = abs(item.tag)
            let mask = value & mode

            item.isEnabled = mask != 0
        }
    }

    // MARK: - NSMenu Delegate
    func menuWillOpen(_ menu: NSMenu) {
        toggleVisibility(false, ofAlternatesKeyEquivalentsItems: menu.items)
        updateMenuItems(items: menu.items, for: window.state.mode.rawValue)
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleVisibility(true, ofAlternatesKeyEquivalentsItems: menu.items)
    }
}
