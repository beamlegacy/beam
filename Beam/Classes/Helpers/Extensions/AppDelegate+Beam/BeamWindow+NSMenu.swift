//
//  BeamWindow+NSMenu.swift
//  Beam
//
//  Created by Remi Santos on 05/07/2021.
//

import Foundation

/// NSMenu bar methods handling
extension BeamWindow {
    @IBAction func newDocument(_ sender: Any?) {
        AppDelegate.main.createWindow(frame: nil, reloadState: false)
    }

    @IBAction func showPreviousTab(_ sender: Any?) {
        state.browserTabsManager.showPreviousTab()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        state.browserTabsManager.showNextTab()
    }

    @IBAction func showJournal(_ sender: Any?) {
        state.navigateToJournal(note: nil)
    }

    @IBAction func toggleScoreCard(_ sender: Any?) {
        state.data.showTabStats.toggle()
    }

    @IBAction func newSearch(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func openLocation(_ sender: Any?) {
        state.focusOmnibox()
    }

    @IBAction func showCardSelector(_ sender: Any?) {
        state.destinationCardIsFocused = true
    }

    // MARK: Navigation
    @IBAction func goBack(_ sender: Any?) {
        state.goBack()
    }

    @IBAction func goForward(_ sender: Any?) {
        state.goForward()
    }

    @IBAction func toggleBetweenWebAndNote(_ sender: Any) {
        state.toggleBetweenWebAndNote()
    }

    @IBAction private func checkForUpdates(_ sender: Any) {
        data.versionChecker.checkForUpdates()
    }

    // MARK: Web loading
    @IBAction func stopLoading(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.stopLoading()
    }

    @IBAction func reload(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.reload()
    }

    @IBAction func resetZoom(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.zoomReset()
    }

    @IBAction func zoomIn(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.zoomIn()
    }

    @IBAction func zoomOut(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.zoomOut()
    }

    @IBAction func showRecentCard(_ sender: Any?) {
        let recents = state.recentsManager.recentNotes
        if let item = sender as? NSMenuItem, let index = Int(item.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()), index <= recents.count {
            state.navigateToNote(named: recents[index - 1].title)
        }
    }

    @IBAction func dumpBrowsingTree(_ sender: Any?) {
        state.browserTabsManager.currentTab?.dumpBrowsingTree()
    }
}

// MARK: - NSMenuItemValidation delegate
extension BeamWindow {
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        AppDelegate.main.validateMenuItem(menuItem)
    }
}
