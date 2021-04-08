//
//  TableView.swift
//  Beam
//
//  Created by Remi Santos on 31/03/2021.
//

import SwiftUI

private enum CellIdentifiers {
    static let DefaultCell = NSUserInterfaceItemIdentifier("DefaultCellID")
}

struct TableViewColumn {
    enum ColumnType {
        case Text
        case CheckBox
    }
    let key: String
    let title: String
    var type: ColumnType = .Text
    var editable = false
    var sortable = true
    var resizable = true
    var width: CGFloat = 100
    var stringFromKeyValue: ((Any?) -> String) = { value in
        return value as? String ?? ""
    }
}

class TableViewItem: NSObject { }

struct TableView: NSViewRepresentable {

    static let rowHeight: CGFloat = 32.0

    var items: [TableViewItem] = []
    var columns: [TableViewColumn] = []
    var creationRowTitle: String = "New Private Card"
    var onEditingText: ((String?, Int) -> Void)?
    var onSelectionChanged: ((IndexSet) -> Void)?
    var onHover: ((Int?, NSRect?) -> Void)?
    var onRightMouseDown: ((Int, NSPoint) -> Void)?

    typealias NSViewType = NSScrollView

    func makeCoordinator() -> TableViewCoordinator {
        TableViewCoordinator(self)
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let scrollView = NSScrollView()
        let view = BeamNSTableView()
        view.onRightMouseDown = onRightMouseDown
        view.backgroundColor = .clear
        view.frame = scrollView.bounds
        view.autoresizingMask = [.width, .height]
        view.allowsMultipleSelection = true
        view.allowsColumnReordering = false
        view.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        if #available(OSX 11.0, *) {
            view.style = .plain
        }
        scrollView.documentView = view
        context.coordinator.tableView = view
        view.delegate = context.coordinator
        view.dataSource = context.coordinator
        setupColumns(in: view, context: context)

        scrollView.contentView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator,
                                               selector: #selector(TableViewCoordinator.contentOffsetDidChange(notification:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        return scrollView
    }

    private func setupColumns(in tableView: NSTableView, context: Self.Context) {
        // Columns setup
        columns.forEach { (column) in
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.key))
            tableColumn.headerCell.title = column.title
            tableColumn.minWidth = column.width
            tableColumn.width = column.width
            if !column.resizable {
                tableColumn.resizingMask = .userResizingMask
            }
            if column.sortable {
                tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.key, ascending: true)
            }
            if column.type == .CheckBox {
                let headerCell = CheckBoxTableHeaderCell(textCell: tableColumn.headerCell.title)
                tableColumn.headerCell = headerCell
                context.coordinator.setupSelectAllCheckBox()
            } else {
                let attrs = NSAttributedString(string: tableColumn.headerCell.title, attributes: [
                    NSAttributedString.Key.foregroundColor: BeamColor.Generic.placeholder.nsColor,
                    NSAttributedString.Key.font: BeamFont.medium(size: 12).nsFont
                ])
                tableColumn.headerCell.attributedStringValue = attrs
            }
            tableView.addTableColumn(tableColumn)
        }
    }

    func updateNSView(_ view: Self.NSViewType, context: Self.Context) {
        context.coordinator.creationRowTitle = creationRowTitle
        context.coordinator.originalData = items
    }
}

private class BeamNSTableView: NSTableView {

    var onRightMouseDown: ((Int, NSPoint) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)

        if let handler = onRightMouseDown {
            let localLocation = convert(event.locationInWindow, from: nil)
            let row = self.row(at: localLocation)
            handler(row, event.locationInWindow)
        }
    }
}

class TableViewCoordinator: NSObject {

    weak var tableView: NSTableView?
    var selectAllCheckBox: CheckBoxButton?
    var originalData = [TableViewItem]() {
        didSet {
            if originalData != oldValue {
                reloadData()
            }
        }
    }
    var creationRowTitle: String?
    private var creationgRowTextField: NSTextField?

    private var sortedData = [TableViewItem]()
    private var sortDescriptor: NSSortDescriptor?

    private var currentSelectedIndexes: IndexSet?
    private var hoveredRow: Int?

    let parent: TableView
    init(_ tableView: TableView) {
        self.parent = tableView
        sortedData = originalData
        super.init()
        reloadData()
    }

    func reloadData() {
        // Sort descriptor is complexe with non-nsobject skipping for now
        if let descriptor = sortDescriptor, let sorted = NSArray(array: originalData).sortedArray(using: [descriptor]) as? [TableViewItem] {
            sortedData = sorted
        } else {
            sortedData = originalData
        }
        currentSelectedIndexes = nil
        parent.onSelectionChanged?([])
        tableView?.reloadData()
        updateSelectAllCheckBox()
    }

    func setupSelectAllCheckBox() {
        let box = CheckBoxButton(checkboxWithTitle: "", target: self, action: #selector(toggleSelectAllRows))
        box.frame.origin = CGPoint(x: 6, y: 5)
        selectAllCheckBox = box
        selectAllCheckBox?.allowsMixedState = true
        tableView?.headerView?.addSubview(box)
    }

    func updateSelectAllCheckBox() {
        let indexesCount = currentSelectedIndexes?.count ?? 0
        if indexesCount == sortedData.count, sortedData.count > 0 {
            selectAllCheckBox?.checked = true
        } else if indexesCount > 0 && (indexesCount != 1 || !isRowCreationRow(currentSelectedIndexes?.first ?? -1) ) {
            selectAllCheckBox?.mixedState = true
        } else {
            selectAllCheckBox?.checked = false
        }
    }

    @objc func contentOffsetDidChange(notification: Notification) {
        if let hovered = hoveredRow,
           let rowView = tableView?.rowView(atRow: hovered, makeIfNecessary: false) as? BeamTableRowView {
            rowView.offsetChanged()
            parent.onHover?(nil, nil)
        }
        hoveredRow = nil
    }
}

extension TableViewCoordinator: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sortedData.count + (creationRowTitle != nil ? 1 : 0)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = BeamTableRowView()
        rowView.isEmphasized = false
        rowView.wantsLayer = true
        if isRowCreationRow(row) {
            rowView.highlightOnSelection = false
        }
        rowView.onHover = { hovering in
            self.hoveredRow = hovering ? row : nil
            self.parent.onHover?(self.hoveredRow, hovering ? tableView.convert(rowView.frame, to: nil) : nil)
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first else {
            return
        }
        sortDescriptor = descriptor
        tableView.deselectAll(self)
        reloadData()
    }

    @objc
    func toggleSelectAllRows() {
        if currentSelectedIndexes?.count == sortedData.count {
            tableView?.deselectAll(self)
        } else {
            tableView?.selectRowIndexes(IndexSet(integersIn: 0..<sortedData.count), byExtendingSelection: true)
        }
    }

    private func getOriginalDataIndexes(for indexes: IndexSet) -> IndexSet {
        var finalIndexes = IndexSet()
        indexes.forEach { (idx) in
            if idx >= 0, idx < sortedData.count {
                let item = sortedData[idx]
                if let originalIndex = originalData.firstIndex(where: { $0 == item }) {
                    finalIndexes.insert(originalIndex)
                }
            }
        }
        return finalIndexes
    }
}

extension TableViewCoordinator: NSTableViewDelegate {

    private func isRowCreationRow(_ row: Int) -> Bool {
        return row == sortedData.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell: NSView?
        guard let column = self.parent.columns.first(where: { $0.key == tableColumn?.identifier.rawValue }) else {
            return nil
        }

        if isRowCreationRow(row) {
            // creationg row
            if column.type == .CheckBox {
                let iconCell = BeamTableCellIconView()
                iconCell.updateWithIcon(NSImage(named: "tabs-new"))
                cell = iconCell
            } else {
                let textCell = BeamTableCellView()
                textCell.textField?.isEditable = false
                if column.editable {
                    textCell.textField?.placeholderAttributedString = NSAttributedString(string: creationRowTitle ?? "", attributes: [.foregroundColor: BeamColor.Generic.placeholder.nsColor, .font: BeamFont.medium(size: 13).nsFont])
                    textCell.textField?.isEditable = true
                    creationgRowTextField = textCell.textField
                    textCell.textField?.delegate = self
                }
                cell = textCell
            }
        } else if column.type == .CheckBox {
            let checkCell = CheckBoxTableCellView()
            checkCell.checked = tableView.selectedRowIndexes.contains(row)
            checkCell.onCheckChange = { selected in
                if selected {
                    tableView.selectRowIndexes([row], byExtendingSelection: true)
                } else {
                    tableView.deselectRow(row)
                }
            }
            cell = checkCell
        } else {
            let textCell = BeamTableCellView()
            let item = sortedData[row]
            let value = item.value(forKey: column.key)
            let text = column.stringFromKeyValue(value)
            let editable = column.editable
            textCell.textField?.stringValue = text
            textCell.textField?.isEditable = editable
            textCell.textField?.delegate = self
            cell = textCell
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return TableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if isRowCreationRow(row) {
            tableView.deselectAll(tableView)
            if let tf = creationgRowTextField {
                tf.becomeFirstResponder()
            }
        }
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            let selectedIndexes = tableView.selectedRowIndexes
            parent.onSelectionChanged?(getOriginalDataIndexes(for: selectedIndexes))
            if let toUnchecked = currentSelectedIndexes?.subtracting(selectedIndexes) {
                setChecked(false, for: toUnchecked, in: tableView)
            }
            setChecked(true, for: selectedIndexes, in: tableView)
            currentSelectedIndexes = selectedIndexes
            updateSelectAllCheckBox()
        }
    }

    private func setChecked(_ checked: Bool, for rows: IndexSet, in tableView: NSTableView) {
        guard let checkColumnIndex = parent.columns.firstIndex(where: { $0.type == .CheckBox }) else {
            return
        }
        rows.forEach { (rowIndex) in
            if let row = tableView.rowView(atRow: rowIndex, makeIfNecessary: false), let cell = row.view(atColumn: checkColumnIndex) as? CheckBoxTableCellView {
                cell.checked = checked
            }
        }
    }

    func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
        if let column = parent.columns.first(where: { $0.key == tableColumn.identifier.rawValue }), column.type == .CheckBox {
            toggleSelectAllRows()
        }
    }
}

extension TableViewCoordinator: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let value = textField.stringValue
        guard !value.isEmpty else {
            tableView?.reloadData()
            return
        }
        if let row = tableView?.row(for: textField),
           let originalDataRow = row == sortedData.count ? originalData.count : getOriginalDataIndexes(for: [row]).first {
            parent.onEditingText?(value, originalDataRow)
        }
    }
}
