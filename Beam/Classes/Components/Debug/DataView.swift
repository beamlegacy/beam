//
//  DataView.swift
//  Beam
//
//  Created by Sébastien Metrot on 09/06/2022.
//

import Foundation
import AppKit
import Combine
import BeamCore

protocol MenuOutlineViewDelegate: NSOutlineViewDelegate {
    func outlineView(outlineView: NSOutlineView, menuForItem item: Any?) -> NSMenu?
}

class DataTreeOutlineView: NSOutlineView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = self.convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        let item = self.item(atRow: row)

        if item == nil {
            return nil
        }

        return (self.delegate as? MenuOutlineViewDelegate)?.outlineView(outlineView: self, menuForItem: item)
    }

}

class DataView: NSView, NSOutlineViewDataSource, MenuOutlineViewDelegate, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    let splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    let outline = DataTreeOutlineView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    let detail = TreeDetailView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

    let root: DataTreeNode

    required init(coder: NSCoder) {
        fatalError()
    }

    init(root: DataTreeNode) {
        self.root = root
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 100))

        splitView.isVertical = false
        splitView.arrangesAllSubviews = true
        splitView.dividerStyle = .paneSplitter
        splitView.autoresizingMask = [.width, .height]
        addSubview(splitView)

        detail.translatesAutoresizingMaskIntoConstraints = false

        outline.autoresizingMask = [.width, .height]
        scrollView.documentView = outline

        let dateWidth = CGFloat(75)
        let minWidth: [DataTreeColumn: CGFloat] = [.tree: 200, .created: dateWidth, .updated: dateWidth, .type: 50, .journalDate: dateWidth]
        let maxWidth: [DataTreeColumn: CGFloat] = [.created: dateWidth, .updated: dateWidth, .type: 50, .journalDate: dateWidth]
        for column in DataTreeColumn.allCases {
            let tableColumn = NSTableColumn(identifier: .init(rawValue: column.rawValue))
            tableColumn.title = column.rawValue
            tableColumn.isEditable = false
            if let minW = minWidth[column] {
                tableColumn.minWidth = minW
            }
            if let maxW = maxWidth[column] {
                tableColumn.maxWidth = maxW
            }
            outline.addTableColumn(tableColumn)
        }
        outline.dataSource = self
        outline.delegate = self

        outline.expandItem(root)
        for db in root.children where db as? DatabaseTreeNode != nil {
            outline.expandItem(db)
            for collection in db.children where collection as? NoteCollectionTreeNode != nil {
                outline.expandItem(collection)
            }
        }

        splitView.setPosition(200, ofDividerAt: 0)

        splitView.addArrangedSubview(scrollView)
        splitView.addArrangedSubview(detail)

        setupObservers()
    }

    var scope = [AnyCancellable]()
    func setupObservers() {
        BeamDocumentCollection.documentDeleted
            .sink { [weak self] deletedDoc in
            guard let self = self else { return }
            if let item = self.root.find(deletedDoc.id) {
                if let parent = item.parent {
                    self.outline.reloadItem(parent, reloadChildren: true)
                }
                self.detail.reloadIfItemIsDetailed(item)
            }
        }.store(in: &scope)

        BeamDocumentCollection.documentSaved
            .receive(on: DispatchQueue.main)
            .sink { [weak self] savedDoc in
            guard let self = self else { return }
            if let item = self.root.find(savedDoc.id) {
                self.outline.reloadItem(item, reloadChildren: true)
                self.detail.reloadIfItemIsDetailed(item)
            }
        }.store(in: &scope)

        DataTreeNode.nodeChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] node in
            guard let self = self else { return }
            self.outline.reloadItem(node, reloadChildren: true)
            self.detail.reloadIfItemIsDetailed(node)
        }.store(in: &scope)
    }

    // MARK: Outline view datasource:
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard item != nil else {
            return 1
        }
        guard let node = item as? DataTreeNode else { return 0 }
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard item != nil else {
            return root
        }
        guard let node = item as? DataTreeNode else { fatalError() }
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? DataTreeNode else { return false }
        return node.isExpandable
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        item
    }

    // MARK: Outline view delegate:
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? DataTreeNode,
              let colName = tableColumn?.identifier.rawValue,
              let column = DataTreeColumn(rawValue: colName)
        else { return nil }

        let documentNode = node as? DocumentTreeNode
        let databaseNode = node as? DatabaseTreeNode

        switch column {
        case .tree:
            return TreeCellView(node.label)

        case .id:
            return cell(node.id)

        case .created:
            return cell(documentNode?.document?.createdAt ?? databaseNode?.database?.createdAt)
        case .updated:
            return cell(documentNode?.document?.updatedAt ?? databaseNode?.database?.updatedAt)
        case .type:
            if let type = documentNode?.document?.documentType {
                return cell("\(type)")
            }
        case .journalDate:
            if documentNode?.document?.documentType == .journal, let date = documentNode?.document?.journalDate {
                return cell("\(date)")
            }
        }

        return nil
    }

    /* View Based OutlineView: See the delegate method -tableView:rowViewForRow: in NSTableView.
     */
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        nil
    }

    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? DataTreeNode else { return }

        node.expand()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? DataTreeNode else { return }

        node.collapse()
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard outline.numberOfSelectedRows == 1,
              let node = outline.item(atRow: outline.selectedRow) as? DataTreeNode
        else {
            clearDetails()
            return
        }

        detail.setupFor(node)
    }

    var itemUnderMenu: Any?

    func outlineView(outlineView: NSOutlineView, menuForItem item: Any?) -> NSMenu? {
        outline.selectRowIndexes(IndexSet(integer: outline.row(forItem: item)), byExtendingSelection: false)
        itemUnderMenu = item
        let menu = NSMenu(title: "Context menu")

        if let documentNode = item as? DocumentTreeNode {
            menu.addItem(withTitle: "Delete", action: #selector(deleteDocument), keyEquivalent: "")
        } else if let databaseNode = item as? DatabaseTreeNode {
            if databaseNode.database?.isLoaded == true {
                menu.addItem(withTitle: "Unload", action: #selector(unloadDatabase), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Load", action: #selector(loadDatabase), keyEquivalent: "")
            }

            if databaseNode.database?.deletedAt == nil {
                menu.addItem(withTitle: "Delete", action: #selector(deleteDatabase), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Undelete", action: #selector(undeleteDatabase), keyEquivalent: "")
            }
            menu.addItem(withTitle: "Hard delete", action: #selector(hardDeleteDatabase), keyEquivalent: "")
        } else if let accountNode = item as? AccountTreeNode {
            menu.addItem(withTitle: "Hard delete", action: #selector(hardDeleteAccount), keyEquivalent: "")
        }
        return menu
    }

    @objc func deleteDocument(_ sender: Any) {
        guard let documentNode = itemUnderMenu as? DocumentTreeNode else { return }
        try? documentNode.document?.collection?.delete(self, filters: [.id(documentNode.documentId)])
    }

    @objc func loadDatabase(_ sender: Any) {
        guard let databaseNode = itemUnderMenu as? DatabaseTreeNode else { return }
        _ = try? databaseNode.database?.account?.loadDatabase(databaseNode.id)
    }

    @objc func unloadDatabase(_ sender: Any) {
        guard let databaseNode = itemUnderMenu as? DatabaseTreeNode else { return }
        try? databaseNode.database?.account?.unloadDatabase(databaseNode.id)
    }

    @objc func deleteDatabase(_ sender: Any) {
        guard let databaseNode = itemUnderMenu as? DatabaseTreeNode else { return }
        databaseNode.database?.deletedAt = BeamDate.now
        try? databaseNode.database?.save(self)
    }

    @objc func undeleteDatabase(_ sender: Any) {
        guard let databaseNode = itemUnderMenu as? DatabaseTreeNode else { return }
        databaseNode.database?.deletedAt = nil
        try? databaseNode.database?.save(self)
    }

    @objc func hardDeleteDatabase(_ sender: Any) {
        guard let databaseNode = itemUnderMenu as? DatabaseTreeNode else { return }
        try? databaseNode.database?.delete(self)
    }

    @objc func hardDeleteAccount(_ sender: Any) {
        guard let accountNode = itemUnderMenu as? AccountTreeNode else { return }
        try? accountNode.account?.delete(self)
    }

    func clearDetails() {
        detail.setupFor(nil)
    }
}

extension NSView {
    func cell(_ string: String?) -> TreeCellView? {
        guard let string = string else { return nil }
        return TreeCellView(string)
    }

    func cell(_ id: UUID?) -> TreeCellView? {
        guard id != UUID.null else { return nil }
        return cell(id?.uuidString)
    }

    func cell(_ date: Date?) -> TreeCellView? {
        return cell(date?.localDayString())
    }

    func cell(_ url: URL?) -> TreeCellView? {
        return cell(url?.string)
    }

    func cell(_ data: Data?) -> TreeCellView? {
        return cell("Blob(\(data?.count ?? 0))")
    }

    func cell(_ data: Bool?) -> TreeCellView? {
        guard let data = data else { return nil }
        return cell("\(data)")
    }
}
