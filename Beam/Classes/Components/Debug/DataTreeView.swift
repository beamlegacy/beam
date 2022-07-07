//
//  DataTreeView.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/06/2022.
//

import Foundation
import SwiftUI
import BeamCore
import GRDB
import Combine

enum DataTreeColumn: String, CaseIterable {
    case tree, id, created, updated, type, journalDate
}

class DataTreeNode: Identifiable {
    var id: UUID
    var name: String
    var label: String { name }
    var children: [DataTreeNode] = []
    var reloadOnChange = true
    public private(set) var parent: DataTreeNode?

    init(parent: DataTreeNode?, id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    func updateChildren() {
    }

    func clear() {
        children = []
    }

    func expand() {
        updateChildren()
    }

    func collapse() {
    }

    var isExpandable = true

    func find(_ id: UUID) -> DataTreeNode? {
        if self.id == id { return self }
        for child in children {
            if let found = child.find(id) {
                return found
            }
        }

        return nil
    }

    var scope = [AnyCancellable]()
    static let nodeChanged = PassthroughSubject<DataTreeNode, Never>()
}

class AccountTreeNode: DataTreeNode {
    weak var account: BeamAccount?
    override var label: String { "🧑‍💻 " + name }

    init(parent: DataTreeNode?, _ account: BeamAccount) {
        self.account = account
        super.init(parent: parent, id: account.id, name: account.name)
    }

    override func updateChildren() {
        guard let account = account else {
            children = []
            return
        }

        children = [ManagersTreeNode(parent: self, account)] + account.allDatabases.map({ db in
            DatabaseTreeNode(parent: self, db)
        })
    }
}

class DatabaseTreeNode: DataTreeNode {
    weak var database: BeamDatabase?
    override var label: String { "💼 " + name }

    init(parent: DataTreeNode?, _ db: BeamDatabase) {
        self.database = db
        super.init(parent: parent, id: db.id, name: db.title)
    }

    override func updateChildren() {
        guard let database = database else {
            children = []
            return
        }

        let _children = database.managers.values.compactMap({ manager -> DataTreeNode? in
            if let collection = manager as? BeamDocumentCollection {
                return NoteCollectionTreeNode(parent: self, collection)
            }

            return nil
        })

        let otherManagers = ManagersTreeNode(parent: self, database)
        children = [otherManagers] + _children
    }
}

class ManagersTreeNode: DataTreeNode {
    weak var holder: BeamManagerOwner?
    override var label: String { "💪 " + name }

    init(parent: DataTreeNode?, _ holder: BeamManagerOwner) {
        self.holder = holder
        super.init(parent: parent, id: UUID.null, name: "Managers")
    }

    override func updateChildren() {
        guard let holder = holder else {
            children = []
            return
        }

        children = holder.managers.values.compactMap({ GenericManagerTreeNode(parent: self, $0) })
    }
}

class GenericManagerTreeNode: DataTreeNode {
    weak var manager: BeamManager?
    override var label: String { "👮‍♂️ " + name }

    init(parent: DataTreeNode?, _ manager: BeamManager) {
        self.manager = manager
        super.init(parent: parent, id: UUID.null, name: manager.managerName)
        isExpandable = false
    }

    override func updateChildren() {
        children = []
    }
}

class NoteCollectionTreeNode: DataTreeNode {
    weak var collection: BeamDocumentCollection?
    var documentIds = Set<UUID>()
    override var label: String { "🗃 " + name }

    init(parent: DataTreeNode?, _ collection: BeamDocumentCollection) {
        self.collection = collection
        super.init(parent: parent, id: UUID.null, name: "Notes")

        collection.observeIds([], nil).sink { _ in
        } receiveValue: { [weak self] documentIds in
            guard let self = self else { return }
            self.updateChildren(documentIds: documentIds)
        }.store(in: &scope)

    }

    override func updateChildren() {
        guard let collection = collection else {
            children = []
            return
        }

        updateChildren(documentIds: try? collection.fetchIds(filters: []))
    }

    func updateChildren(documentIds: [UUID]?) {
        guard let documentIds = documentIds,
              let collection = collection
        else {
            children = []
            return
        }

        var existing = [UUID: DataTreeNode]()
        for node in children {
            existing[node.id] = node
        }

        children = documentIds.map { documentId -> DataTreeNode in
            if let existingdoc = existing[documentId] as? DocumentTreeNode {
                return existingdoc
            }
            return DocumentTreeNode(parent: self, collection, documentId)
        }
    }
}

class DocumentTreeNode: DataTreeNode {
    weak var collection: BeamDocumentCollection?
    var documentId: UUID
    var _document: BeamDocument?
    var document: BeamDocument? {
        guard let _document = _document else {
            _document = try? collection?.fetchFirst(filters: [.id(documentId)])
            return _document
        }
        return _document
    }

    override var label: String { (document?.documentType == .journal ? "🗞 " : "📝 ") + name }

    init(parent: DataTreeNode?, _ collection: BeamDocumentCollection, _ documentId: UUID) {
        self.collection = collection
        self.documentId = documentId
        let title = (try? collection.fetchTitles(filters: [.id(documentId)]).first) ?? "???"
        super.init(parent: parent, id: documentId, name: title)
        isExpandable = false
        reloadOnChange = false

        BeamDocumentCollection.documentSaved.sink { [weak self] savedDocument in
            guard let self = self else { return }
            // Only update if the document was already loaded
            self.update(savedDocument)
        }.store(in: &scope)

        BeamDocumentCollection.documentDeleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deletedDocument in
            guard let self = self else { return }
            if deletedDocument.id == documentId {
                Self.nodeChanged.send(self)
            }
        }.store(in: &scope)
    }

    func update(_ document: BeamDocument) {
        if document.id == documentId, _document != nil {
            _document = document
            Self.nodeChanged.send(self)
        }
    }

}

struct DataTreeView: NSViewRepresentable {
    typealias NSViewType = DataView
    var treeRoot: DataTreeNode

    func makeNSView(context: Context) -> NSViewType {
        let view = DataView(root: treeRoot)
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}
