//
//  AllNotesPageContextualMenu.swift
//  Beam
//
//  Created by Remi Santos on 08/04/2021.
//

import Foundation
import BeamCore


protocol AllNotesPageContextualMenuDelegate: AnyObject {
    func contextualMenuShouldPublishNote() -> Bool
    func contextualMenuWillUndoRedoDeleteDocuments()
    func contextualMenuWillDeleteDocuments(ids: [UUID], all: Bool)
}

class AllNotesPageContextualMenu {

    private let selectedNotes: [BeamNote]
    private let onLoadBlock: ((_ isLoading: Bool) -> Void)?
    private let onFinishBlock: ((_ needReload: Bool) -> Void)?
    private let cmdManager = CommandManagerAsync<BeamDocumentCollection>()

    var undoManager: UndoManager?
    weak var delegate: AllNotesPageContextualMenuDelegate?

    init(selectedNotes: [BeamNote], onLoad: ((_ isLoading: Bool) -> Void)? = nil, onFinish: ((_ needReload: Bool) -> Void)? = nil) {
        self.selectedNotes = selectedNotes
        self.onLoadBlock = onLoad
        self.onFinishBlock = onFinish
    }

    // swiftlint:disable function_body_length
    func presentMenuForNotes(at: CGPoint, allowImports: Bool = false) {
        guard let window = AppDelegate.main.window else { return }
        let menu = NSMenu()
        menu.font = BeamFont.regular(size: 13).nsFont

        let allIds = selectedNotes.map { $0.id }
        let containsToday =  allIds.contains(BeamData.shared.todaysNote.id)

        var countSuffix = " All"
        if selectedNotes.count > 0 {
            let count = selectedNotes.count
            countSuffix = count == 1 ? "" : " \(count) Notes"

            guard let pinnedManager = AppDelegate.main.window?.state.data.pinnedManager else { return }

            if selectedNotes.allSatisfy({ !pinnedManager.isPinned($0) }) {
                menu.addItem(NSMenuItem(title: "Pin",
                                        action: #selector(pin),
                                        keyEquivalent: ""))
            }

            if selectedNotes.allSatisfy({ pinnedManager.isPinned($0) }) {
                menu.addItem(NSMenuItem(title: "Unpin",
                                        action: #selector(unpin),
                                        keyEquivalent: ""))
            }

            if let first = selectedNotes.first, first.publicationStatus.isPublic {
                menu.addItem(NSMenuItem(
                    title: "Unpublish\(countSuffix)",
                    action: #selector(makePrivate),
                    keyEquivalent: ""
                ))
            } else {
                menu.addItem(NSMenuItem(
                    title: "Publish\(countSuffix)",
                    action: #selector(makePublic),
                    keyEquivalent: ""
                ))
            }

            if selectedNotes.allSatisfy({ !$0.publicationStatus.isOnPublicProfile && $0.publicationStatus.isPublic }) {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(
                    title: "Publish\(countSuffix) on Profile",
                    action: #selector(publishOnProfile),
                    keyEquivalent: ""
                ))
            }

            if selectedNotes.allSatisfy({ $0.publicationStatus.isOnPublicProfile }) {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(
                    title: "Unpublish\(countSuffix) from Profile",
                    action: #selector(unpublishFromProfile),
                    keyEquivalent: ""
                ))
            }
            menu.addItem(NSMenuItem.separator())

        }

        if allowImports {
            setupImportMenu(in: menu)
        }

       setupExportMenu(in: menu, countSuffix: countSuffix)

        if !(allIds.count == 1 && containsToday) {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(
                title: "Delete\(countSuffix)...",
                action: #selector(deleteNotes),
                keyEquivalent: ""
            ))
        }

        finalizeAllMenuItems(menu.items)
        let position = CGRect(origin: at, size: .zero).flippedRectToBottomLeftOrigin(in: window).origin
        menu.popUp(positioning: nil, at: position, in: window.contentView)
    }

    private func setupImportMenu(in menu: NSMenu) {
        let importMenu = NSMenu()
        importMenu.addItem(NSMenuItem(
            title: "Roam...",
            action: #selector(roamImport),
            keyEquivalent: ""
        ))
        importMenu.addItem(NSMenuItem(
            title: "Backup...",
            action: #selector(backupImport),
            keyEquivalent: ""
        ))
        importMenu.addItem(NSMenuItem(
            title: "JSON...",
            action: #selector(importFromJSON),
            keyEquivalent: ""
        ))
        let importItem = NSMenuItem(
            title: "Import",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(importItem)
        menu.setSubmenu(importMenu, for: importItem)
    }

    private func setupExportMenu(in menu: NSMenu, countSuffix: String) {
        let exportMenu = NSMenu()
        #if BEAM_BETA
        exportMenu.addItem(NSMenuItem(
            title: "beamNote...",
            action: nil,
            keyEquivalent: ""
        ))
        #else
        exportMenu.addItem(NSMenuItem(
            title: "beamNote...",
            action: #selector(exportNotesToBeamNote),
            keyEquivalent: ""
        ))
        #endif
//        if false {
//            exportMenu.addItem(NSMenuItem(
//                title: "Markdown...",
//                action: nil,
//                keyEquivalent: ""
//            ))
//        }
        if selectedNotes.count <= 0 {
            #if BEAM_BETA
            exportMenu.addItem(NSMenuItem(
                title: "Entire database...",
                action: nil,
                keyEquivalent: ""
            ))
            #else
            exportMenu.addItem(NSMenuItem(
                title: "Entire database...",
                action: #selector(databaseExport),
                keyEquivalent: ""
            ))
            #endif
        }
        let exportItem = NSMenuItem(
            title: "Export\(countSuffix)",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(exportItem)
        menu.setSubmenu(exportMenu, for: exportItem)
    }

    private func finalizeAllMenuItems(_ items: [NSMenuItem]) {
        items.forEach { item in
            item.target = self
            if let subItems = item.submenu?.items {
                finalizeAllMenuItems(subItems)
            }
        }
    }

    @objc private func roamImport() {
        AppDelegate.main.importRoam(self)
    }

    @objc private func backupImport() {
        AppDelegate.main.importNotes(self)
    }

    @objc private func databaseExport() {
        // only support export all notes for now
        AppDelegate.main.exportNotes(self)
    }

    @objc private func importFromJSON() {
        AppDelegate.main.importJSONFiles(self)
    }

    @objc private func exportNotesToBeamNote() {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }
        let selectedNotesCount = selectedNotes.count
        if selectedNotes.count == 1 {
            AppDelegate.main.exportOneNoteToBeamNote(note: selectedNotes[0])
        } else if selectedNotesCount != .zero, selectedNotes.count != (try? collection.count(filters: [])) ?? 0 {
            AppDelegate.main.exportNotesToBeamNote(selectedNotes)
        } else {
            AppDelegate.main.exportAllNotesToBeamNote(self)
        }
    }

    @objc
    private func publishOnProfile() {
        Task { @MainActor in
            await updateProfileGroup(publish: true)
            self.onFinishBlock?(true)
        }
    }

    @objc
    private func unpublishFromProfile() {
        Task { @MainActor in
            await updateProfileGroup(publish: false)
            self.onFinishBlock?(true)
        }
    }

    private func updateProfileGroup(publish: Bool) async {
        await withTaskGroup(of: Void.self, body: { group in
            for note in selectedNotes where note.publicationStatus.isPublic {
                group.addTask {
                    await withCheckedContinuation { continuation in

                        var publicationGroups = note.publicationStatus.publicationGroups ?? []
                        if note.publicationStatus.isOnPublicProfile {
                            guard let idx = publicationGroups.firstIndex(where: { $0 == "profile" }) else { return }
                            publicationGroups.remove(at: idx)
                        } else {
                            publicationGroups.append("profile")
                        }

                        BeamNoteSharingUtils.updatePublicationGroup(note, publicationGroups: publicationGroups) { _ in
                            continuation.resume()
                        }
                    }
                }
            }
        })
    }

    @objc private func makePublic() {
        guard delegate?.contextualMenuShouldPublishNote() != false else {
            return
        }
        Task { @MainActor in
            await makeNotes(isPublic: true)
            self.onFinishBlock?(true)
        }
    }

    @objc private func makePrivate() {
        Task { @MainActor in
            await makeNotes(isPublic: false)
            self.onFinishBlock?(true)
        }
    }

    private func makeNotes(isPublic: Bool) async {
        await withTaskGroup(of: Void.self, body: { group in
            _ = selectedNotes.map { note in
                group.addTask {
                    await withCheckedContinuation { continuation in
                        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: isPublic) { _ in
                            continuation.resume()
                        }
                    }
                }
            }
        })
    }

    @objc private func deleteNotes() {
        let alert = NSAlert()
        let messageNotesInfo = selectedNotes.count == 1 ?
            "this note" :
            selectedNotes.count == 0 ?
            "all notes" :
            "these \(selectedNotes.count) notes"
        alert.messageText = "Are you sure you want to delete \(messageNotesInfo)?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AppDelegate.main.window else { return }
        alert.beginSheetModal(for: window) { (response) in
            if response == .alertFirstButtonReturn {
                self.confirmedDeleteSelectedNotes()
            } else {
                self.onFinishBlock?(false)
            }
        }
    }

    private func confirmedDeleteSelectedNotes() {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }
        guard selectedNotes.count > 0 else {
            onLoadBlock?(true)
            self.delegate?.contextualMenuWillDeleteDocuments(ids: [], all: true)
            cmdManager.deleteAllDocuments(in: collection) { _ in
                DispatchQueue.main.async {
                    self.registerUndo(actionName: "Delete All Notes")
                    self.onFinishBlock?(true)
                }
            }
            return
        }
        onLoadBlock?(true)
        let ids = selectedNotes.map { $0.id }
        self.delegate?.contextualMenuWillDeleteDocuments(ids: ids, all: false)
        cmdManager.deleteDocuments(ids: ids, in: collection) { _ in
            DispatchQueue.main.async {
                let count = ids.count
                self.registerUndo(actionName: "Delete \(count) Note\(count > 1 ? "s" : "")")
                self.onFinishBlock?(true)
            }
        }
    }

    private func registerUndo(redo: Bool = false, actionName: String) {
        guard let undoManager = undoManager else {
            return
        }
        AllNotesMenuUndoRegisterer(undoManager: undoManager, cmdManager: cmdManager, menuDelegate: delegate)
            .registerUndo(redo: redo, actionName: actionName)
    }

    @objc private func pin() {
        guard let window = AppDelegate.main.window else { return }
        window.state.data.pinnedManager.pin(notes: selectedNotes)
    }

    @objc private func unpin() {
        guard let state = AppDelegate.main.window?.state else { return }
        state.data.pinnedManager.unpin(notes: selectedNotes)
    }
}

/// Using a separate struct that can be kept in memory by the UndoManager instead of the whole ContextualMenu class
private class AllNotesMenuUndoRegisterer {
    let undoManager: UndoManager?
    let cmdManager: CommandManagerAsync<BeamDocumentCollection>
    weak var menuDelegate: AllNotesPageContextualMenuDelegate?

    init(undoManager: UndoManager,
         cmdManager: CommandManagerAsync<BeamDocumentCollection>,
         menuDelegate: AllNotesPageContextualMenuDelegate?) {
        self.undoManager = undoManager
        self.cmdManager = cmdManager
        self.menuDelegate = menuDelegate
    }

    func registerUndo(redo: Bool = false, actionName: String) {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }

        undoManager?.registerUndo(withTarget: self, handler: { _ in
            self.registerUndo(redo: !redo, actionName: actionName)
            let completion: (Bool) -> Void = { _ in
                self.menuDelegate?.contextualMenuWillUndoRedoDeleteDocuments()
            }
            if redo {
                self.cmdManager.redoAsync(context: collection, completion: completion)
            } else {
                self.cmdManager.undoAsync(context: collection, completion: completion)
            }
        })
        undoManager?.setActionName(actionName)
    }
}
