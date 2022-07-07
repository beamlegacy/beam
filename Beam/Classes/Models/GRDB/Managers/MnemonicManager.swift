//
//  MnemonicManager.swift
//  Beam
//
//  Created by Sébastien Metrot on 14/06/2022.
//

import Foundation
import GRDB
import BeamCore

class MnemonicManager: GRDBHandler, BeamManager {
    weak public private(set) var holder: BeamManagerOwner?
    static var id = UUID()

    static var name = "MnemonicManager"

    required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    public override var tableNames: [String] { ["MnemonicRecord"] }

    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("create_MnemonicRecord") { db in
            try db.create(table: "MnemonicRecord", ifNotExists: true) { t in
                t.column("text", .text).unique(onConflict: .replace).primaryKey()
                t.column("url", .text)
                t.column("last_visited_at", .date)
            }
        }
    }

    // MARK: - MnemonicRecord

    /// Register the URL in the history table associated with a `last_visited_at` timestamp.
    /// - Parameter urlId: URL identifier from the LinkStore
    /// - Parameter url: URL to the page
    /// - Parameter title: Title of the page indexed in FTS
    /// - Parameter text: Content of the page indexed in FTS
    func insertMnemonic(text: String, url: UUID) throws {
        try self.write { db in
            try MnemonicRecord(text: text.lowercased(), url: url, lastVisitedAt: BeamDate.now).insert(db)
        }
    }

    func getMnemonic(text: String) -> URL? {
        guard let mnemonic = try? self.read({ try MnemonicRecord.filter(MnemonicRecord.Columns.text == text.lowercased()).fetchOne($0) }),
        let link = LinkStore.shared.linkFor(id: mnemonic.url)?.url,
            let url = URL(string: link) else {
                return nil
            }
        return url
    }
}

extension BeamManagerOwner {
    var mnemonicManager: MnemonicManager? {
        try? manager(MnemonicManager.self)
    }
}

extension BeamData {
    var mnemonicManager: MnemonicManager? {
        currentAccount?.mnemonicManager
    }
}
