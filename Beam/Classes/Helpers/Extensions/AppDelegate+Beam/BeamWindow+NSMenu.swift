//
//  BeamWindow+NSMenu.swift
//  Beam
//
//  Created by Remi Santos on 05/07/2021.
//

import Foundation

/// NSMenu bar methods handling
///
/// :warning: be careful when naming these method, if the storyboard points to firstResponder:methodName but the actual first responder (text field, webview, etc.)
/// has a method with that exact name, it will be called instead of the window's implementation.
/// Sometimes it can be a desired effect, sometimes not.
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

    @IBAction func reOpenClosedTab(_ sender: Any?) {
        if state.cmdManager.canUndo {
            if state.mode != .web {
                state.mode = .web
            }
            _ = state.cmdManager.undo(context: state)
        } else if !ClosedTabDataPersistence.savedCloseTabData.isEmpty {
            restoreTabs(from: ClosedTabDataPersistence.savedCloseTabData)
            ClosedTabDataPersistence.savedCloseTabData.removeAll()
            ClosedTabDataPersistence.savedTabsData.removeAll()
        } else if !ClosedTabDataPersistence.savedTabsData.isEmpty {
            restoreTabs(from: ClosedTabDataPersistence.savedTabsData)
            ClosedTabDataPersistence.savedTabsData.removeAll()
        }
    }

    private func restoreTabs(from data: Data) {
        let decoder = JSONDecoder()
        guard let windowCommands = try? decoder.decode([Int: GroupWebCommand].self, from: data) else { return }
        for windowCommand in windowCommands.keys {
            guard var beamWindow = AppDelegate.main.windows.first,
                    let command = windowCommands[windowCommand] else { continue }
            if windowCommand > 0 {
                beamWindow = AppDelegate.main.createWindow(frame: nil, restoringTabs: false)
            }
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
        if state.focusOmniBox && (state.mode != .web || state.focusOmniBoxFromTab) {
            state.focusOmniBox = false
        } else {
            state.setFocusOmnibox(fromTab: true)
        }
    }

    @IBAction func openDocument(_ sender: Any?) {
        state.startNewSearch()
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
    @IBAction func stopLoadingPage(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.stopLoading()
    }

    @IBAction func reloadPage(_ sender: Any) {
        state.browserTabsManager.reloadCurrentTab()
    }

    @IBAction func resetPageZoom(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.zoomReset()
    }

    @IBAction func zoomPageIn(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.zoomIn()
    }

    @IBAction func zoomPageOut(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.zoomOut()
    }

    @IBAction func dumpBrowsingTree(_ sender: Any?) {
        state.browserTabsManager.currentTab?.dumpBrowsingTree()
    }

    @IBAction func collectPageToCard(_ sender: Any?) {
        state.browserTabsManager.currentTab?.collectTab()
    }

    @IBAction func openRecentNote(_ sender: NSMenuItem) {
        let recentsNotes = state.recentsManager.recentNotes
        guard let id = recentsNotes.first(where: { $0.title == sender.title })?.id else { return }
        state.navigateToNote(id: id)
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
