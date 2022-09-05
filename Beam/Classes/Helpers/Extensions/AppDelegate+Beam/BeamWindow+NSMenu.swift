//
//  BeamWindow+NSMenu.swift
//  Beam
//
//  Created by Remi Santos on 05/07/2021.
//

import Foundation
import BeamCore

/// NSMenu bar methods handling
///
/// :warning: be careful when naming these method, if the storyboard points to firstResponder:methodName but the actual first responder (text field, webview, etc.)
/// has a method with that exact name, it will be called instead of the window's implementation.
/// Sometimes it can be a desired effect, sometimes not.
extension BeamWindow {
    @IBAction func checkForUpdate(_ sender: Any?) {
        state.data.checkForUpdate()
    }

    @IBAction func toggleSidebar(_ sender: Any?) {
        if state.useSidebar {
            state.showSidebar.toggle()
        }
    }

    @IBAction func showPreviousTab(_ sender: Any?) {
        state.showPreviousTab()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        state.showNextTab()
    }

    @IBAction func duplicateTab(_ sender: Any?) {
        guard let currentTab = state.browserTabsManager.currentTab else { return }
        state.duplicate(tab: currentTab)
    }

    @IBAction func showJournal(_ sender: Any?) {
        state.navigateToJournal(note: nil, clearNavigation: true)
    }

    @IBAction func showAllNotes(_ sender: Any?) {
        state.navigateToPage(.allNotesWindowPage)
    }

    @IBAction func toggleScoreCard(_ sender: Any?) {
        state.data.showTabStats.toggle()
    }

    @IBAction func newSearch(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func newNote(_ sender: Any?) {
        state.startNewNote()
    }

    @IBAction func createEmptyTabWithCurrentNote(_ sender: Any?) {
        state.startNewSearchWithCurrentDestinationCard()
    }

    @IBAction func reOpenClosedTab(_ sender: Any?) {
        if state.cmdManager.canUndo,
            (state.cmdManager.lastCmd is CloseTab || (state.cmdManager.lastCmd as? GroupCommand)?.commands.first is CloseTab) {
            if state.mode != .web {
                state.mode = .web
            }
            _ = state.cmdManager.undo(context: state)
        } else {
            AppDelegate.main.reopenAllWindowsFromLastSession()
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
        if state.omniboxInfo.isFocused &&
            (state.mode != .web || state.omniboxInfo.wasFocusedFromTab) &&
            (!state.omniboxInfo.isShownInJournal || !state.autocompleteManager.autocompleteResults.isEmpty) {
            state.stopFocusOmnibox()
            if state.omniboxInfo.isShownInJournal {
                state.autocompleteManager.clearAutocompleteResults()
            }
        } else {
            state.startFocusOmnibox(fromTab: true)
        }
    }

    @IBAction func togglePinNote(_ sender: Any?) {
        guard let note = state.currentNote else { return }
        state.data.pinnedManager.togglePin(note)
    }

    @IBAction func openDocument(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func muteCurrentTab(_ sender: Any?) {
        if let currentTabIsPlaying = state.browserTabsManager.currentTab?.mediaPlayerController?.isPlaying, currentTabIsPlaying {
            state.browserTabsManager.currentTab?.mediaPlayerController?.setMuted(true)
        }
    }

    @IBAction func copyCurrentTabURL(_ sender: Any?) {
        guard let currentTab = state.browserTabsManager.currentTab else { return }
        currentTab.copyURLToPasteboard()
    }

    @IBAction func muteOtherTabs(_ sender: Any?) {
        for tab in state.browserTabsManager.tabs where tab != state.browserTabsManager.currentTab {
            if let tabIsPlaying = tab.mediaPlayerController?.isPlaying, tabIsPlaying {
                tab.mediaPlayerController?.setMuted(true)
            }
        }
    }

    @IBAction func showHelp(_ sender: Any?) {
        showHelpAndFeedbackMenuView()
    }

    @IBAction func toggleStatusBar(_ sender: Any?) {
        PreferencesManager.showsStatusBar.toggle()
    }

    // MARK: Navigation
    @IBAction func navigateBack(_ sender: Any?) {
        let newTab = NSApp.currentEvent.map({ ($0.type != .keyDown) && $0.modifierFlags.contains(.command) }) ?? false
        state.goBack(openingInNewTab: newTab)
    }

    @IBAction func navigateForward(_ sender: Any?) {
        let newTab = NSApp.currentEvent.map({ ($0.type != .keyDown) && $0.modifierFlags.contains(.command) }) ?? false
        state.goForward(openingInNewTab: newTab)
    }

    @IBAction func toggleBetweenWebAndNote(_ sender: Any) {
        state.toggleBetweenWebAndNote()
    }

    // MARK: Web loading
    @IBAction func stopLoadingPage(_ sender: Any) {
        state.browserTabsManager.currentTab?.webView.stopLoading()
    }

    @IBAction func reloadPage(_ sender: Any) {
        state.browserTabsManager.reloadCurrentTab()
    }

    @IBAction func resetPageZoom(_ sender: Any) {
        state.browserTabsManager.currentTab?.zoom(.reset)
    }

    @IBAction func zoomPageIn(_ sender: Any) {
        state.browserTabsManager.currentTab?.zoom(.in)
    }

    @IBAction func zoomPageOut(_ sender: Any) {
        state.browserTabsManager.currentTab?.zoom(.out)
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

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == KeyCode.escape.rawValue && state.browserTabsManager.currentTab?.shouldHijackEscapeKey() == true {
            return keyDown(with: event)
        }
        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape.rawValue {
            switch state.mode {
            case .web:
                state.browserTabsManager.currentTab?.respondToEscapeKey()
            case .note:
                state.currentEditor?.searchViewModel?.close()
            default:
                break
            }
        }
        if event.keyCode == KeyCode.tab.rawValue {
            if event.modifierFlags.contains(.control) && state.mode == .web {
                if event.modifierFlags.contains(.shift) {
                    state.browserTabsManager.showPreviousTab()
                } else {
                    state.browserTabsManager.showNextTab()
                }
                return
            }
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
            guard PreferencesManager.cmdNumberSwitchTabs, command else { return }
            if state.mode == .web && keyValue <= state.browserTabsManager.tabs.count {
                state.browserTabsManager.setCurrentTab(atAbsoluteIndex: keyValue - 1)
            } else if state.mode != .web {
                let recents = state.recentsManager.recentNotes
                if keyValue <= recents.count {
                    state.navigateToNote(id: recents[keyValue - 1].id)
                }
            }
        case KeyCode.nine.rawValue:
            guard PreferencesManager.cmdNumberSwitchTabs, command, case .web = state.mode else { return }
            state.browserTabsManager.setCurrentTab(at: state.browserTabsManager.tabs.count - 1)
        default:
            break
        }
        super.keyDown(with: event)
    }
}

// MARK: - NSMenuItemValidation delegate
extension BeamWindow {
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undo(_:)) {
            if let undoManager = firstResponder?.undoManager, undoManager.canUndo {
                menuItem.title = undoManager.undoMenuItemTitle
                return true
            }
            if state.mode == .web && state.cmdManager.canUndo {
                menuItem.title = state.cmdManager.undoMenuItemTitle
                return true
            }
            menuItem.title = NSLocalizedString("Undo", comment: "Menu Item")
            return false
        }
        if menuItem.action == #selector(redo(_:)) {
            if let undoManager = firstResponder?.undoManager, undoManager.canRedo {
                menuItem.title = undoManager.redoMenuItemTitle
                return true
            }
            if state.mode == .web && state.cmdManager.canRedo {
                menuItem.title = state.cmdManager.redoMenuItemTitle
                return true
            }
            menuItem.title = NSLocalizedString("Redo", comment: "Menu Item")
            return false
        }
        return AppDelegate.main.validateMenuItem(menuItem)
    }
}
