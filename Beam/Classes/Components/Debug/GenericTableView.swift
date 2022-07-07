//
//  GenericTableView.swift
//  Beam
//
//  Created by Sébastien Metrot on 10/06/2022.
//

import Foundation
import GRDB
import BeamCore

class GenericManagerTableView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var manager: BeamManager
    let tableView = NSTableView()

    init(manager: BeamManager, frame: CGRect) {
        self.manager = manager

        super.init(frame: frame)

        let tableNames = (manager as? GRDBHandler)?.tableNames ?? []
        guard !tableNames.isEmpty
        else {
            return
        }

        let scrollView = NSScrollView()
        scrollView.frame = NSRect(origin: NSPoint(), size: self.frame.size)
        scrollView.autoresizingMask = [.width, .height]

        scrollView.documentView = tableView

        let stackView = NSStackView(frame: CGRect(origin: .zero, size: frame.size))
        stackView.orientation = .vertical
        stackView.autoresizingMask = [.width, .height]
        addSubview(stackView)

        let displayType = NSSegmentedControl(labels: tableNames, trackingMode: .selectOne, target: self, action: #selector(genericTableChanged))
        displayType.selectedSegment = 0
        displayType.autoresizingMask = [.width, .height]
        displayType.sizeToFit()

        stackView.distribution = .fillProportionally

        let topView = NSStackView(frame: CGRect(origin: .zero, size: frame.size))
        topView.addArrangedSubview(displayType)
        let checkButton = NSButton(title: "🩺", target: self, action: #selector(checkTables))
        let fixButton = NSButton(title: "⛑", target: self, action: #selector(fixTables))
        topView.addArrangedSubview(checkButton)
        topView.addArrangedSubview(fixButton)
        topView.addArrangedSubview(displayType)

        stackView.addArrangedSubview(topView)
        stackView.addArrangedSubview(scrollView)

        if let tableName = tableNames.first {
            currentTable = tableName
            loadTable(tableName)
        }

        tableView.delegate = self
        tableView.dataSource = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func genericTableChanged(_ sender: Any) {
        guard let handler = manager as? GRDBHandler,
              let control = sender as? NSSegmentedControl, control.selectedSegment < handler.tableNames.count
        else { return }

        loadTable(handler.tableNames[control.selectedSegment])
    }

    var currentTable = ""
    func loadTable(_ tableName: String) {
        currentTable = tableName

        for column in tableView.tableColumns {
            tableView.removeTableColumn(column)
        }

        guard let handler = manager as? GRDBHandler else {
            return
        }

        guard let rows: [Row] = try? handler.read({ db in
            do {
                return try handler.read { db in
                    try Row.fetchAll(db, sql: "SELECT name FROM PRAGMA_TABLE_INFO('\(tableName)')")
                }
            } catch {
                Logger.shared.logError("error fetching table names: \(error)", category: .database)
                throw error
            }
        })
        else { return }

        for colrow in rows {
            let col: String = colrow["name"]
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: col))
            column.title = col
            tableView.addTableColumn(column)
        }

        reloadData()
    }

    var rows = [Row]()
    func reloadData() {
        rows = []
        guard let handler = manager as? GRDBHandler else { return }

        rows = (try? handler.read({ db in
            try? handler.read { db in
                try Row.fetchAll(db, sql: "SELECT * FROM \(self.currentTable)")
            }
        })) ?? []

        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let handler = manager as? GRDBHandler else { return 0 }

        return (try? handler.read { db in
            do {
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(self.currentTable)")
            } catch {
                Logger.shared.logError("Unable to fetch the number of raw in \(self.currentTable): \(error)", category: .database)
                throw error
            }
        }) ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowData = rows[row]
        guard let identifier = tableColumn?.identifier.rawValue, rowData.hasColumn(identifier) else { return nil }

        let dbValue: DatabaseValue = rowData[identifier]
        if let value = String.fromDatabaseValue(dbValue) {
            return cell(value)
        } else if let value = UUID.fromDatabaseValue(dbValue) {
            return cell(value)
        } else if let value = Int.fromDatabaseValue(dbValue) {
            return cell("\(value)")
        } else if let value = Double.fromDatabaseValue(dbValue) {
            return cell("\(value)")
        } else if let value = URL.fromDatabaseValue(dbValue) {
            return cell(value)
        } else if let value = Data.fromDatabaseValue(dbValue) {
            return cell(value)
        } else if let value = Date.fromDatabaseValue(dbValue) {
            return cell(value)
        } else if let value = Bool.fromDatabaseValue(dbValue) {
            return cell(value)
        }

        return nil

    }

    @objc func checkTables() {
        guard let handler = manager as? GRDBHandler else { return }
        for table in handler.tableNames {
            do {
                try handler.write { db in
                    if handler.isFTSEnabled(on: table) {
                        try db.execute(sql: "INSERT INTO \(table)(\(table)) VALUES('integrity-check')")
                    }
                    try db.execute(sql: "PRAGMA main.quick_check(\(table))")
                }
            } catch {
                let msg = "Error in GRDB table \(table): \(error)"
                Logger.shared.logError(msg, category: .database)
                UserAlert.showAlert(message: msg)
            }
        }
    }

    @objc func fixTables() {
        guard let handler = manager as? GRDBHandler else { return }
        for table in handler.tableNames {
            do {
                try handler.write { db in
                    if handler.isFTSEnabled(on: table) {
                        try db.execute(sql: "INSERT INTO \(table)(\(table)) VALUES('rebuild')")
                    }
                }
            } catch {
                let msg = "Error while fixing GRDB table \(table): \(error)"
                Logger.shared.logError(msg, category: .database)
                UserAlert.showAlert(message: msg)
            }
        }
    }
}
