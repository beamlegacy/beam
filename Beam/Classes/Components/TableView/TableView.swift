//
//  TableView.swift
//  Beam
//
//  Created by Remi Santos on 31/03/2021.
//
// swiftlint:disable file_length

import SwiftUI

class TableViewItem: NSObject {
    var placeholder: String?
}

class IconAndTextTableViewItem: TableViewItem {
    var favIcon: NSImage?
    var text: String?

    override init() {
        super.init()
    }
}

class TwoTextFieldViewItem: IconAndTextTableViewItem {
    var topTextFieldValue: String?
    var topTextFieldPlaceholder: String?
    var botTextFieldValue: String?
    var botTextFieldPlaceholder: String?

    override init() {
        super.init()
    }
}

struct TableView: NSViewRepresentable {

    static let rowHeight: CGFloat = 32.0
    static let headerHeight: CGFloat = 32.0

    var customRowHeight: CGFloat?
    var hasSeparator: Bool = true
    var hasHeader: Bool = true
    var allowsMultipleSelection: Bool = true
    var items: [TableViewItem] = []
    var columns: [TableViewColumn] = []
    var creationRowTitle: String? = "New Private Card"
    @Binding var shouldReloadData: Bool?

    var onEditingText: ((String?, Int) -> Void)?
    var onSelectionChanged: ((IndexSet) -> Void)?
    var onHover: ((_ row: Int?, _ location: NSRect?) -> Void)?
    var onMouseDown: ((_ row: Int, _ column: TableViewColumn) -> Void)?
    var onRightMouseDown: ((Int, _ column: TableViewColumn, NSPoint) -> Void)?

    typealias NSViewType = NSScrollView

    func makeCoordinator() -> TableViewCoordinator {
        TableViewCoordinator(self)
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let scrollView = NSScrollView()
        let view = BeamNSTableView()
        view.backgroundColor = .clear
        view.frame = scrollView.bounds
        view.autoresizingMask = [.width, .height]
        view.allowsMultipleSelection = allowsMultipleSelection
        view.allowsColumnReordering = false
        view.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        if #available(OSX 11.0, *) {
            view.style = .plain
        }
        scrollView.documentView = view
        context.coordinator.tableView = view
        view.delegate = context.coordinator
        view.additionalDelegate = context.coordinator
        view.dataSource = context.coordinator
        setupColumns(in: view, context: context)
        if !hasHeader {
            view.headerView = nil
        }
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator,
                                               selector: #selector(TableViewCoordinator.contentOffsetDidChange(notification:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        return scrollView
    }

    private func setupColumns(in tableView: NSTableView, context: Self.Context) {
        var initialSortDescriptor: NSSortDescriptor?
        columns.forEach { (column) in
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.key))
            tableColumn.headerCell.title = column.title
            tableColumn.minWidth = column.width
            tableColumn.width = column.width
            if !column.resizable {
                tableColumn.resizingMask = .userResizingMask
            }
            if column.sortable {
                tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.key,
                                                                       ascending: column.sortableDefaultAscending)
                if column.isInitialSortDescriptor {
                    initialSortDescriptor = tableColumn.sortDescriptorPrototype
                }
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
        if let sortDescriptor = initialSortDescriptor {
            tableView.sortDescriptors = [sortDescriptor]
        }
    }

    func updateNSView(_ view: Self.NSViewType, context: Self.Context) {
        context.coordinator.creationRowTitle = creationRowTitle
        context.coordinator.originalData = items
        if shouldReloadData == true {
            context.coordinator.reloadData(soft: true)
            self.shouldReloadData = false
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
    var creationRowTitle: String? {
        didSet {
            if creationRowTitle != oldValue {
                reloadData()
            }
        }
    }
    private var creationgRowTextField: NSTextField?

    private var sortedData = [TableViewItem]()
    private var sortDescriptor: NSSortDescriptor?

    private var currentSelectedIndexes: IndexSet?
    private var hoveredRow: Int?

    let parent: TableView
    var hasSeparator: Bool
    var customRowHeight: CGFloat?

    init(_ tableView: TableView) {
        self.parent = tableView
        self.hasSeparator = tableView.hasSeparator
        self.customRowHeight = tableView.customRowHeight
        super.init()
        reloadData()
        DispatchQueue.main.async {
            self.tableView?.scroll(CGPoint(x: 0, y: -TableView.headerHeight))
        }
    }

    /// - Parameters:
    ///   - soft: keep selection or not
    func reloadData(soft: Bool = false) {
        if let descriptor = sortDescriptor, let sorted = NSArray(array: originalData).sortedArray(using: [descriptor]) as? [TableViewItem] {
            sortedData = sorted
        } else {
            sortedData = originalData
        }
        if !soft {
            currentSelectedIndexes = nil
            parent.onSelectionChanged?([])
        }
        tableView?.reloadData()
        if soft, let selectedIndexes = currentSelectedIndexes {
            tableView?.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        }
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
        rowView.hasSeparator = hasSeparator
        rowView.isEmphasized = false
        rowView.wantsLayer = true
        if isRowCreationRow(row) {
            rowView.highlightOnSelection = false
        }
        rowView.onHover = { hovering in
            guard rowView.frame.origin.y >= tableView.visibleRect.origin.y else { return }
            let rowFrame = tableView.convert(rowView.frame, to: nil)
            self.hoveredRow = hovering ? row : nil
            self.parent.onHover?(self.hoveredRow, hovering ? rowFrame : nil)
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
        guard let column = self.parent.columns.first(where: { $0.key == tableColumn?.identifier.rawValue }) else {
            return nil
        }

        if isRowCreationRow(row) {
            // creation row
            if column.type == .CheckBox {
                let iconCell = BeamTableCellIconView()
                iconCell.updateWithIcon(NSImage(named: "tabs-new"))
                return iconCell
            } else {
                let textCell = BeamTableCellView()
                textCell.textField?.isEditable = false
                if column.editable {
                    textCell.textField?.placeholderAttributedString = NSAttributedString(string: creationRowTitle ?? "", attributes: [.foregroundColor: BeamColor.Generic.placeholder.nsColor, .font: BeamFont.medium(size: 13).nsFont])
                    textCell.textField?.isEditable = true
                    creationgRowTextField = textCell.textField
                    textCell.textField?.delegate = self
                }
                return textCell
            }
        }
        switch column.type {
        case .CheckBox:
            return setupCheckBoxCell(tableView, at: row)
        case .Text:
            return setupTextCell(tableView, at: row, column: column)
        case .IconAndText:
            return setupIconAndTextCell(tableView, at: row, column: column)
        case .TwoTextField:
            return setupTwoTextFieldViewCell(tableView, at: row, column: column)
        }
    }

    private func setupTextCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn) -> BeamTableCellView {
        let textCell = BeamTableCellView()
        let item = sortedData[row]
        let value = item.value(forKey: column.key)
        let text = column.stringFromKeyValue(value)
        let editable = column.editable && !column.isLink
        textCell.textField?.stringValue = text
        textCell.textField?.isEditable = editable
        textCell.textField?.font = BeamFont.regular(size: column.fontSize).nsFont
        if let textColor = column.fontColor {
            textCell.textField?.textColor = textColor
        }
        textCell.isLink = column.isLink
        textCell.textField?.delegate = self
        return textCell
    }

    private func setupCheckBoxCell(_ tableView: NSTableView, at row: Int) -> CheckBoxTableCellView {
        let checkCell = CheckBoxTableCellView()
        checkCell.checked = tableView.selectedRowIndexes.contains(row)
        checkCell.onCheckChange = { selected in
            if selected {
                tableView.selectRowIndexes([row], byExtendingSelection: true)
            } else {
                tableView.deselectRow(row)
            }
        }
        return checkCell
    }

    private func setupIconAndTextCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn)
    -> BeamTableCellIconAndTextView {
        let iconAndTextCell = BeamTableCellIconAndTextView()
        let item = sortedData[row] as? IconAndTextTableViewItem
        iconAndTextCell.updateWithIcon(item?.favIcon)
        let editable = column.editable && !column.isLink
        iconAndTextCell.textField?.stringValue = item?.text ?? ""
        iconAndTextCell.textField?.isEditable = editable
        iconAndTextCell.textField?.font = BeamFont.regular(size: column.fontSize).nsFont
        if let textColor = column.fontColor {
            iconAndTextCell.textField?.textColor = textColor
        }
        iconAndTextCell.textField?.delegate = self
        return iconAndTextCell
    }

    private func setupTwoTextFieldViewCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn) -> BeamTableCellTwoTextFieldView {
        let twoTextFieldViewCell = BeamTableCellTwoTextFieldView()
        let item = sortedData[row] as? TwoTextFieldViewItem
        let editable = column.editable && !column.isLink

        twoTextFieldViewCell.topTextField.stringValue = item?.topTextFieldValue ?? ""
        twoTextFieldViewCell.botTextField.stringValue = item?.botTextFieldValue ?? ""
        twoTextFieldViewCell.topTextField.placeholderString = item?.topTextFieldPlaceholder
        twoTextFieldViewCell.botTextField.placeholderString = item?.botTextFieldPlaceholder

        twoTextFieldViewCell.topTextField.isEditable = editable
        twoTextFieldViewCell.botTextField.isEditable = editable
        twoTextFieldViewCell.topTextField.font = BeamFont.regular(size: column.fontSize).nsFont
        twoTextFieldViewCell.botTextField.font = BeamFont.regular(size: column.fontSize).nsFont
        if let textColor = column.fontColor {
            twoTextFieldViewCell.topTextField.textColor = textColor
            twoTextFieldViewCell.botTextField.textColor = textColor
        }
        return twoTextFieldViewCell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let customRowHeight = self.customRowHeight else {
            return TableView.rowHeight
        }
        return customRowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if isRowCreationRow(row) {
            tableView.deselectAll(tableView)
            if let tf = creationgRowTextField {
                tf.becomeFirstResponder()
            }
            return false
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

extension TableViewCoordinator: BeamNSTableViewDelegate {

    func tableView(_ tableView: BeamNSTableView, mouseDownFor row: Int, column: Int, locationInWindow: NSPoint) -> Bool {
        let view = tableView.view(atColumn: column, row: row, makeIfNecessary: false)

        // if mouseDown in checkbox column
        if view is CheckBoxTableCellView {
            if currentSelectedIndexes?.contains(row) == true {
                tableView.deselectRow(row)
            } else {
                tableView.selectRowIndexes([row], byExtendingSelection: true)
            }
            return false
        }

        // if mouseDown in a column handling click
        if let onMouseDown = parent.onMouseDown,
              let cellView = view as? BeamTableCellView,
              let originalRow = getOriginalDataIndexes(for: [row]).first,
              column < parent.columns.count,
              cellView.shouldHandleMouseDown(at: cellView.convert(locationInWindow, from: nil)) {
            let columnData = parent.columns[column]
            onMouseDown(originalRow, columnData)
            return false
        }

        return true
    }

    func tableView(_ tableView: BeamNSTableView, rightMouseDownFor row: Int, column: Int, locationInWindow: NSPoint) {
        guard let onRightMouseDown = parent.onRightMouseDown,
              let originalRow = getOriginalDataIndexes(for: [row]).first,
              column < parent.columns.count
        else { return }
        let columnData = parent.columns[column]
        onRightMouseDown(originalRow, columnData, locationInWindow)
    }
}
