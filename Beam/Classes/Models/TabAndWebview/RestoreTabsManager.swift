//
//  RestoreTabsManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/11/2021.
//

import Foundation
import BeamCore

/// A class that saves the currently opened browser tabs when closing the app or a window.
/// To re-open them if needed.
final class RestoreTabsManager {

    static let shared = RestoreTabsManager()

    private var appWindows: [BeamWindow] {
        AppDelegate.main.windows
    }

    private func saveOpenedTabs(isTerminatingApp: Bool, onlyForThisWindow onlyWindow: BeamWindow? = nil) {
        let windowsToSave: [BeamWindow]
        if let onlyWindow = onlyWindow {
            windowsToSave = [onlyWindow]
        } else {
            windowsToSave = appWindows
        }
        guard windowsToSave.contains(where: { $0.state.hasBrowserTabs }) else {
            if isTerminatingApp {
                clearSavedClosedTabs()
            }
            return
        }
        var windowForTabsCmd = [Int: Command<BeamState>]()
        let tmpCmdManager = CommandManager<BeamState>()

        for window in windowsToSave where window.state.hasBrowserTabs {
            let windowID = window.windowNumber
            tmpCmdManager.beginGroup(with: ClosedTabDataPersistence.closeTabCmdGrp)
            let tabsManager = window.state.browserTabsManager
            for tab in tabsManager.tabs.reversed() where tab.url != nil {
                guard let index = tabsManager.tabs.firstIndex(of: tab) else { continue }
                // Since we don't run the cmd when closing the app we need to do this out of the CloseTab Cmd
                if isTerminatingApp {
                    tab.appWillClose()
                }
                if tab.isPinned { continue }
                let closeTabCmd = CloseTab(tab: tab, appIsClosing: true, tabIndex: index, wasCurrentTab: tabsManager.currentTab === tab,
                                           group: tabsManager.group(forTab: tab))

                tmpCmdManager.appendToDone(command: closeTabCmd)
            }
            tmpCmdManager.endGroup(forceGroup: true)

            if let lastCmd = tmpCmdManager.lastCmd {
                windowForTabsCmd[windowID] = lastCmd
            }
        }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(windowForTabsCmd) else { return }
        ClosedTabDataPersistence.savedCloseTabData = data
    }

    private func restoreTabs(from data: Data) {
        let decoder = BeamJSONDecoder()
        guard let windowCommands = try? decoder.decode([Int: GroupWebCommand].self, from: data) else { return }

        // We reopend the tabs in their originated window if they still exist,
        // or we use the current main window for the first bunch of tabs, and next bunchss will have new windows.
        var hasUsedMainWindow = false
        for windowID in windowCommands.keys {
            guard let command = windowCommands[windowID] else { continue }
            var window = appWindows.first(where: { $0.windowNumber == windowID })
            if window == nil {
                if !hasUsedMainWindow, let mainWindow = AppDelegate.main.window {
                    hasUsedMainWindow = true
                    window = mainWindow
                } else {
                    window = AppDelegate.main.createWindow(frame: nil, restoringTabs: false)
                }
            }
            guard let window = window else { continue }

            window.state.cmdManager.appendToDone(command: command)

            if window.state.cmdManager.canUndo {
                _ = window.state.cmdManager.undo(context: window.state)
            }

            if window.state.browserTabsManager.currentTab != nil, window.state.mode != .web {
                window.state.mode = .web
            }
        }
    }

    // MARK: Public Methods

    func saveOpenedTabsBeforeClosingWindow(_ window: BeamWindow) {
        saveOpenedTabs(isTerminatingApp: false, onlyForThisWindow: window)
    }

    func saveOpenedTabsBeforeTerminatingApp() {
        saveOpenedTabs(isTerminatingApp: true)
    }

    /// Checks for saved tabs during last window close or last app termination.
    func reopendSavedClosedTabsIfPossible() {
        let data = ClosedTabDataPersistence.savedCloseTabData
        guard !data.isEmpty else { return }
        clearSavedClosedTabs()
        restoreTabs(from: data)
    }

    func clearSavedClosedTabs() {
        ClosedTabDataPersistence.savedCloseTabData.removeAll()
    }
}

private final class ClosedTabDataPersistence {

    static let closeTabCmdGrp = "CloseTabCmdGrp"

    private static let savedCloseTabCmdsKey = "savedClosedTabCmds"

    @UserDefault(key: savedCloseTabCmdsKey, defaultValue: Data(), suiteName: BeamUserDefaults.savedClosedTabs.suiteName)
    static var savedCloseTabData: Data
}
