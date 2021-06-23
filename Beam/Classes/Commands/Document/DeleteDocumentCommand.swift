//
//  DeleteDocumentCommand.swift
//  Beam
//
//  Created by Remi Santos on 25/05/2021.
//

import Foundation
import BeamCore
import Promises

class DeleteDocument: DocumentCommand {
    static let name: String = "DeleteDocument"

    private var allDocuments = false

    init(documentIds: [UUID] = [], allDocuments: Bool = false) {
        super.init(name: Self.name)
        self.allDocuments = allDocuments
        self.documentIds = documentIds
    }

    override func run(context: DocumentManager?, completion: ((Bool) -> Void)?) {
        if allDocuments {
            documents = context?.loadAll() ?? []
            context?.deleteAll().then { done in
                completion?(done)
            }
        } else {
            documents = documentIds.compactMap {
                context?.loadById(id: $0)
            }
            context?.delete(ids: documentIds).then { done in
                completion?(done)
            }
        }

    }

    override func undo(context: DocumentManager?, completion: ((Bool) -> Void)?) {
        guard !documents.isEmpty else {
            completion?(false)
            return
        }
        documents.forEach {
            _ = context?.save($0, completion: nil)
        }

        let promises: [Promises.Promise<Bool>] = documents.compactMap { context?.save($0) }
        Promises.all(promises).then { dones in
            let done = dones.reduce(into: false) { $0 = $0 || $1 }
            completion?(done)
        }
    }
}

extension CommandManagerAsync where Context == DocumentManager {
    func deleteDocuments(ids: [UUID], in context: DocumentManager, completion: ((Bool) -> Void)? = nil) {
        let cmd = DeleteDocument(documentIds: ids)
        run(command: cmd, on: context, completion: completion)
    }

    func deleteAllDocuments(in context: DocumentManager, completion: ((Bool) -> Void)? = nil) {
        let cmd = DeleteDocument(allDocuments: true)
        run(command: cmd, on: context, completion: completion)
    }
}
