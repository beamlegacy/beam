//
//  AllCardsContextualMenu.swift
//  Beam
//
//  Created by Remi Santos on 08/04/2021.
//

import Foundation
import BeamCore
import Promises

protocol AllCardsContextualMenuDelegate: AnyObject {
    func contextualMenuWillDeleteDocuments(ids: [UUID], all: Bool)
}

class AllCardsContextualMenu {

    private let documentManager: DocumentManager
    private let selectedNotes: [BeamNote]
    private let onLoadBlock: ((_ isLoading: Bool) -> Void)?
    private let onFinishBlock: ((_ needReload: Bool) -> Void)?
    private let cmdManager = CommandManagerAsync<DocumentManager>()

    var undoManager: UndoManager?
    weak var delegate: AllCardsContextualMenuDelegate?

    init(documentManager: DocumentManager, selectedNotes: [BeamNote], onLoad: ((_ isLoading: Bool) -> Void)? = nil, onFinish: ((_ needReload: Bool) -> Void)? = nil) {
        self.documentManager = documentManager
        self.selectedNotes = selectedNotes
        self.onLoadBlock = onLoad
        self.onFinishBlock = onFinish
    }

    func presentMenuForNotes(at: CGPoint, allowImports: Bool = false) {
        let menu = NSMenu()
        menu.font = BeamFont.regular(size: 13).nsFont

        var countSuffix = "All"
        if selectedNotes.count > 0 {
            let count = selectedNotes.count
            countSuffix = count == 1 ? "" : "\(count) Cards"

            if let first = selectedNotes.first, first.isPublic {
                menu.addItem(NSMenuItem(
                    title: "Make Private \(countSuffix)",
                    action: #selector(makePrivate),
                    keyEquivalent: ""
                ))
            } else {
                menu.addItem(NSMenuItem(
                    title: "Make Public \(countSuffix)",
                    action: #selector(makePublic),
                    keyEquivalent: ""
                ))
            }

            if count == 1 {
                menu.addItem(NSMenuItem(
                    title: "Invite...",
                    action: #selector(invite),
                    keyEquivalent: ""
                ))
            }
            menu.addItem(NSMenuItem.separator())
        }

        if allowImports {
            setupImportMenu(in: menu)
        }

       setupExportMenu(in: menu, countSuffix: countSuffix)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Delete \(countSuffix)",
            action: #selector(deleteNotes),
            keyEquivalent: ""
        ))

        finalizeAllMenuItems(menu.items)
        menu.popUp(positioning: nil, at: at, in: AppDelegate.main.window?.contentView)
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
        exportMenu.addItem(NSMenuItem(
            title: "JSON...",
            action: nil,
            keyEquivalent: ""
        ))
        exportMenu.addItem(NSMenuItem(
            title: "Markdown...",
            action: nil,
            keyEquivalent: ""
        ))
        if selectedNotes.count <= 0 {
            exportMenu.addItem(NSMenuItem(
                title: "Entire database...",
                action: #selector(databaseExport),
                keyEquivalent: ""
            ))
        }
        let exportItem = NSMenuItem(
            title: "Export \(countSuffix)",
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
//        only support export all notes for now
        AppDelegate.main.exportNotes(self)
    }

    @objc private func invite() {
//        no-op for now
    }

    @objc private func makePublic() {
        makeNotes(isPublic: true).then { _ in
            self.onFinishBlock?(true)
        }
    }

    @objc private func makePrivate() {
        makeNotes(isPublic: false).then { _ in
            self.onFinishBlock?(true)
        }
    }

    private func makeNotes(isPublic: Bool) -> Promises.Promise<[Bool]> {
        let docManager = documentManager
        let promises: [Promises.Promise<Bool>] = selectedNotes.map { note in
            note.isPublic = isPublic
            return Promises.Promise { (done, error) in
                note.save(documentManager: docManager) { (result) in
                    switch result {
                    case .failure(let e):
                        error(e)
                    case .success(let success):
                        done(success)
                    }
                }
            }
        }
        return Promises.all(promises)
    }

    @objc private func deleteNotes() {
        let alert = NSAlert()
        let messageNotesInfo = selectedNotes.count == 1 ?
            "this card" :
            selectedNotes.count == 0 ?
            "all cards" :
            "these \(selectedNotes.count) cards"
        alert.messageText = "Are you sure you want to delete \(messageNotesInfo)?"
        alert.addButton(withTitle: "Delete...")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AppDelegate.main.window else {
            if alert.runModal() == .alertFirstButtonReturn {
                self.confirmedDeleteSelectedNotes()
            } else {
                self.onFinishBlock?(false)
            }
            return
        }
        alert.beginSheetModal(for: window) { (response) in
            if response == .alertFirstButtonReturn {
                self.confirmedDeleteSelectedNotes()
            } else {
                self.onFinishBlock?(false)
            }
        }

    }

    private func confirmedDeleteSelectedNotes() {
        guard selectedNotes.count > 0 else {
            onLoadBlock?(true)
            self.delegate?.contextualMenuWillDeleteDocuments(ids: [], all: true)
            cmdManager.deleteAllDocuments(in: documentManager) { _ in
                self.registerUndo(actionName: "Delete All Cards")
                self.onFinishBlock?(true)
            }
            return
        }
        onLoadBlock?(true)
        let ids = selectedNotes.map { $0.id }
        self.delegate?.contextualMenuWillDeleteDocuments(ids: ids, all: false)
        cmdManager.deleteDocuments(ids: ids, in: documentManager) { _ in
            let count = ids.count
            self.registerUndo(actionName: "Delete \(count) Card\(count > 1 ? "s" : "")")
            self.onFinishBlock?(true)
        }
    }

    private func registerUndo(redo: Bool = false, actionName: String) {
        undoManager?.registerUndo(withTarget: self, handler: { _ in
            self.registerUndo(redo: !redo, actionName: actionName)
            if redo {
                self.cmdManager.redoAsync(context: self.documentManager) { _ in }
            } else {
                self.cmdManager.undoAsync(context: self.documentManager) { _ in }
            }
        })
        undoManager?.setActionName(actionName)
    }
}
