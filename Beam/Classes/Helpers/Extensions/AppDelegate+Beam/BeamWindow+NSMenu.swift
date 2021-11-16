//
//  BeamWindow+NSMenu.swift
//  Beam
//
//  Created by Remi Santos on 05/07/2021.
//

import Foundation

/// NSMenu bar methods handling
extension BeamWindow {
    @IBAction func showPreviousTab(_ sender: Any?) {
        state.showPreviousTab()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        state.showNextTab()
    }

    @IBAction func showJournal(_ sender: Any?) {
        state.navigateToJournal(note: nil, clearNavigation: true)
    }

    @IBAction func showAllCards(_ sender: Any?) {
        state.navigateToPage(.allCardsWindowPage)
    }

    @IBAction func toggleScoreCard(_ sender: Any?) {
        state.data.showTabStats.toggle()
    }

    @IBAction func newSearch(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func createEmptyTabWithCurrentNote(_ sender: Any?) {
        state.createEmptyTabWithCurrentDestinationCard()
    }

    static let savedCloseTabCmdsKey = "savedClosedTabCmds"
    static let savedTabsKey = "savedTabsKey"
    @IBAction func reOpenClosedTab(_ sender: Any?) {
        if state.cmdManager.canUndo {
            if state.mode != .web {
                state.mode = .web
            }
            _ = state.cmdManager.undo(context: state)
        } else if let data = UserDefaults.standard.data(forKey: Self.savedCloseTabCmdsKey) {
            restoreTabs(from: data)
            UserDefaults.standard.removeObject(forKey: Self.savedCloseTabCmdsKey)
            UserDefaults.standard.removeObject(forKey: Self.savedTabsKey)
        } else if let data = UserDefaults.standard.data(forKey: Self.savedTabsKey) {
            restoreTabs(from: data)
            UserDefaults.standard.removeObject(forKey: Self.savedTabsKey)
        }
    }

    private func restoreTabs(from data: Data) {
        let decoder = JSONDecoder()
        guard let windowCommands = try? decoder.decode([Int: GroupWebCommand].self, from: data) else { return }
        for windowCommand in windowCommands.keys {
            guard let beamWindow = AppDelegate.main.window,
                    let command = windowCommands[windowCommand] else { continue }
            beamWindow.state.cmdManager.appendToDone(command: command)

            if beamWindow.state.cmdManager.canUndo {
                _ = beamWindow.state.cmdManager.undo(context: beamWindow.state)
            }

            if beamWindow.state.browserTabsManager.currentTab != nil, beamWindow.state.mode != .web {
                beamWindow.state.mode = .web
            }
        }
    }

    @IBAction func undo(_ sender: Any) {
        if let firstResponder = self.firstResponder,
           let undoManager = firstResponder.undoManager, undoManager.canUndo {
            undoManager.undo()
            return
        }
        if state.mode == .web && state.cmdManager.canUndo {
            _ = state.cmdManager.undo(context: state)
        }
    }

    @IBAction func redo(_ sender: Any) {
        if let firstResponder = self.firstResponder,
           let undoManager = firstResponder.undoManager, undoManager.canRedo {
            undoManager.redo()
            return
        }
        if state.mode == .web && state.cmdManager.canRedo {
            _ = state.cmdManager.redo(context: state)
        }
    }

    @IBAction func openLocation(_ sender: Any?) {
        state.setFocusOmnibox()
    }

    @IBAction func showCardSelector(_ sender: Any?) {
        state.destinationCardIsFocused = true
    }

    @IBAction func muteCurrentTab(_ sender: Any?) {
        if let currentTabIsPlaying = state.browserTabsManager.currentTab?.mediaPlayerController?.isPlaying, currentTabIsPlaying {
            state.browserTabsManager.currentTab?.mediaPlayerController?.isMuted = true
        }
    }

    @IBAction func muteOtherTabs(_ sender: Any?) {
        for tab in state.browserTabsManager.tabs where tab != state.browserTabsManager.currentTab {
            if let tabIsPlaying = tab.mediaPlayerController?.isPlaying, tabIsPlaying {
                tab.mediaPlayerController?.isMuted = true
            }
        }
    }

    @IBAction func showHelp(_ sender: Any?) {
        state.navigateToPage(.shortcutsWindowPage)
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
        state.browserTabsManager.reloadCurrentTab()
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

    @IBAction func dumpBrowsingTree(_ sender: Any?) {
        state.browserTabsManager.currentTab?.dumpBrowsingTree()
    }

    @IBAction func collectPageToCard(_ sender: Any?) {
        state.browserTabsManager.currentTab?.collectTab()
    }

    // MARK: - Web Navigation

    var shift: Bool { NSEvent.modifierFlags.contains(.shift) }
    var option: Bool { NSEvent.modifierFlags.contains(.option) }
    var control: Bool { NSEvent.modifierFlags.contains(.control) }
    var command: Bool { NSEvent.modifierFlags.contains(.command) }

    // swiftlint:disable:next cyclomatic_complexity
    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape.rawValue {
            state.browserTabsManager.currentTab?.respondToEscapeKey()
        }
        guard let keyValue = KeyCode.getKeyValueFrom(for: event.keyCode) else { return }
        switch event.keyCode {
        case KeyCode.zero.rawValue:
            if command {
                if state.mode != .web {
                    state.navigateToJournal(note: nil)
                }
                if command && state.mode == .web {
                    state.browserTabsManager.currentTab?.webView.zoomReset()
                }
                return
            }
        case KeyCode.one.rawValue, KeyCode.two.rawValue, KeyCode.three.rawValue, KeyCode.four.rawValue, KeyCode.five.rawValue, KeyCode.six.rawValue, KeyCode.seven.rawValue, KeyCode.eight.rawValue:
            if command {
                if state.mode == .web && keyValue <= state.browserTabsManager.tabs.count {
                    state.browserTabsManager.showTab(at: keyValue - 1)
                } else if state.mode != .web {
                    let recents = state.recentsManager.recentNotes
                    if keyValue <= recents.count {
                        state.navigateToNote(id: recents[keyValue - 1].id)
                    }
                }
                return
            }
        case KeyCode.nine.rawValue:
            if command && state.mode == .web {
                state.browserTabsManager.showTab(at: state.browserTabsManager.tabs.count - 1)
                return
            }
        default:
            break
        }
        super.keyDown(with: event)
    }
}

// MARK: - NSMenuItemValidation delegate
extension BeamWindow {
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        AppDelegate.main.validateMenuItem(menuItem)
    }
}
