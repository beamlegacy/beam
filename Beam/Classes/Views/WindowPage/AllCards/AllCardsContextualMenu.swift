//
//  AllCardsContextualMenu.swift
//  Beam
//
//  Created by Remi Santos on 08/04/2021.
//

import Foundation
import BeamCore
import Promises

class AllCardsContextualMenu {

    private let documentManager: DocumentManager
    private let selectedNotes: [BeamNote]
    private let onFinishBlock: ((_ needReload: Bool) -> Void)?

    init(documentManager: DocumentManager, selectedNotes: [BeamNote], onFinish: ((_ needReload: Bool) -> Void)?) {
        self.documentManager = documentManager
        self.selectedNotes = selectedNotes
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
        menu.popUp(positioning: nil, at: at, in: AppDelegate.main.window.contentView)
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
        let promises: [Promises.Promise<Bool>] = selectedNotes.map { note in
            note.isPublic = isPublic
            if let doc = note.documentStruct {
                return documentManager.saveDocument(doc)
            } else {
                let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey: "Couldn't get document struct for note"])
                return Promises.Promise(error)
            }
        }
        return Promises.all(promises)
    }

    @objc private func deleteNotes() {
        let alert = NSAlert()
        let messageNotesInfo = selectedNotes.count == 1 ?
            "this card" :
            "these \(selectedNotes.count) cards"
        alert.messageText = "Are you sure you want to delete \(messageNotesInfo)? This cannot be undone."
        alert.addButton(withTitle: "Delete...")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.beginSheetModal(for: AppDelegate.main.window) { (response) in
            if response == .alertFirstButtonReturn {
                self.confirmedDeleteSelectedNotes()
            } else {
                self.onFinishBlock?(false)
            }
        }

    }

    private func confirmedDeleteSelectedNotes() {
        guard selectedNotes.count > 0 else {
            self.documentManager.deleteAllDocuments().then { _ in
                self.onFinishBlock?(true)
            }
            return
        }
        self.documentManager.deleteDocuments(ids: selectedNotes.map { $0.id }).then { _ in
            self.onFinishBlock?(true)
        }
    }

}
