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

class IconButtonTableViewItem: TableViewItem {
    var iconName: String?
    var hasPopover: Bool = false
    var popoverAlignment: Edge = .top
    var buttonAction: ((NSPoint?) -> Void)?

    override init() {
        super.init()
    }
}

class IconAndTextTableViewItem: TableViewItem {
    var favIcon: NSImage?
    var text: String?

    override init() {
        super.init()
    }

    func loadRemoteFavIcon(completion: @escaping (NSImage) -> Void) {}
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

    static let rowHeight: CGFloat = 28.0
    static let headerHeight: CGFloat = 28.0

    var customRowHeight: CGFloat?
    var hasVerticalScroller = false
    var hasSeparator = true
    var hasHeader = true
    var headerTitleColor: NSColor = BeamColor.AlphaGray.nsColor
    var headerBackgroundColor: NSColor = BeamColor.Generic.background.nsColor
    var allowsMultipleSelection = true
    var items: [TableViewItem] = []
    var columns: [TableViewColumn] = []
    var creationRowTitle: String?
    var isCreationRowLoading = false
    var shouldReloadData: Binding<Bool?>?
    var sortDescriptor: Binding<NSSortDescriptor?>?

    var onEditingText: ((String?, Int) -> Void)?
    var onSelectionChanged: ((IndexSet) -> Void)?
    var onHover: ((_ row: Int?, _ location: NSRect?) -> Void)?
    var onMouseDown: ((_ row: Int, _ column: TableViewColumn) -> Void)?
    var onRightMouseDown: ((Int, _ column: TableViewColumn, NSPoint) -> Void)?
    var onDoubleTap: ((_ row: Int) -> Void)?

    typealias NSViewType = NSScrollView

    func makeCoordinator() -> TableViewCoordinator {
        TableViewCoordinator(self)
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let coordinator = context.coordinator

        let scrollView = NSScrollView()
        let view = BeamNSTableView()
        view.backgroundColor = .clear
        view.frame = scrollView.bounds
        view.autoresizingMask = [.width, .height]
        view.allowsMultipleSelection = allowsMultipleSelection
        view.allowsColumnReordering = false
        view.columnAutoresizingStyle = .reverseSequentialColumnAutoresizingStyle
        view.intercellSpacing = .zero
        view.style = .plain
        view.onHoverTableView = { [weak coordinator] isHovering in
            coordinator?.tableView(isHovered: isHovering)
        }

        scrollView.documentView = view
        context.coordinator.tableView = view
        view.delegate = context.coordinator
        view.additionalDelegate = context.coordinator
        view.dataSource = context.coordinator
        setupColumns(in: view, context: context)
        if !hasHeader {
            view.headerView = nil
        } else {
            var headerFrame = view.headerView?.frame ?? .zero
            headerFrame.size.height = TableView.headerHeight
            let headerView = TableHeaderView()
            let coordinator = context.coordinator
            headerView.onHoverColumn = { [weak coordinator] column, hovering in
                coordinator?.headerViewHoveredColumn(column: column, hovering: hovering)
            }
            view.headerView = headerView
            view.headerView?.frame = headerFrame
        }
        scrollView.horizontalScrollElasticity = .none
        scrollView.hasVerticalScroller = hasVerticalScroller
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
        columns.enumerated().forEach { (index, column) in
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.key))
            let customHeaderCell = TableHeaderCell(textCell: column.title,
                                                   headerTitleColor: self.headerTitleColor,
                                                   headerBackgroundColor: self.headerBackgroundColor)
            customHeaderCell.drawsTrailingBorder = index < columns.count - 1
            customHeaderCell.font = BeamFont.regular(size: 12).nsFont
            tableColumn.headerCell = customHeaderCell
            tableColumn.minWidth = column.width
            tableColumn.width = column.width
            if !column.resizable {
                tableColumn.resizingMask = .userResizingMask
            }
            if column.sortable {
                var prototype = NSSortDescriptor(key: column.key,
                                                 ascending: column.sortableDefaultAscending)
                if column.sortableCaseInsensitive {
                    prototype = NSSortDescriptor(key: column.key,
                                                 ascending: column.sortableDefaultAscending,
                                                 selector: #selector(NSString.caseInsensitiveCompare))
                }
                tableColumn.sortDescriptorPrototype = prototype
                if column.isInitialSortDescriptor {
                    initialSortDescriptor = tableColumn.sortDescriptorPrototype
                }
            }
            if column.type == .CheckBox {
                let headerCell = CheckBoxTableHeaderCell(textCell: tableColumn.headerCell.title)
                tableColumn.headerCell = headerCell
                context.coordinator.selectAllCheckBoxHeaderCell = headerCell
            } else {
                let attrs = NSAttributedString(string: tableColumn.headerCell.title, attributes: [
                    NSAttributedString.Key.foregroundColor: self.headerTitleColor,
                    NSAttributedString.Key.font: BeamFont.regular(size: 12).nsFont
                ])
                tableColumn.headerCell.attributedStringValue = attrs
            }
            tableView.addTableColumn(tableColumn)
        }
        if let sortDescriptor = sortDescriptor?.wrappedValue ?? initialSortDescriptor {
            tableView.sortDescriptors = [sortDescriptor]
        }
    }

    func updateNSView(_ view: Self.NSViewType, context: Self.Context) {
        context.coordinator.creationRowTitle = creationRowTitle
        context.coordinator.isCreationRowLoading = isCreationRowLoading
        context.coordinator.originalData = items
        if shouldReloadData?.wrappedValue == true {
            context.coordinator.reloadData(soft: true)
            self.shouldReloadData?.wrappedValue = false
        }
    }
}

class TableViewCoordinator: NSObject {

    weak var tableView: NSTableView?
    var selectAllCheckBoxHeaderCell: CheckBoxTableHeaderCell?

    var originalData = [TableViewItem]() {
        didSet {
            reloadDataIfPropertyChanged(newValue: originalData, oldValue: oldValue)
        }
    }
    var creationRowTitle: String? {
        didSet {
            reloadDataIfPropertyChanged(newValue: creationRowTitle, oldValue: oldValue)
        }
    }
    var isCreationRowLoading: Bool = false {
        didSet {
            reloadDataIfPropertyChanged(newValue: isCreationRowLoading, oldValue: oldValue)
        }
    }

    private var creationgRowTextField: NSTextField?

    private var sortedData = [TableViewItem]()
    private var sortDescriptor: NSSortDescriptor? {
        didSet {
            parent.sortDescriptor?.wrappedValue = sortDescriptor
        }
    }

    private var currentSelectedIndexes: IndexSet?
    private var hoveredRow: Int?
    /// When appearing the first row is hidden between the header, workaround is to manually scroll when rendering the rows.
    private var shouldResetScrollOnNextReload = false

    let parent: TableView
    var hasSeparator: Bool
    var customRowHeight: CGFloat?

    init(_ tableView: TableView) {
        self.parent = tableView
        self.hasSeparator = tableView.hasSeparator
        self.customRowHeight = tableView.customRowHeight
        self.shouldResetScrollOnNextReload = true
        super.init()
        reloadData()
    }

    /// - Parameters:
    ///   - soft: keep selection or not
    func reloadData(soft: Bool = false) {
        guard tableView?.tableColumns != nil else { return }
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

    private func reloadDataIfPropertyChanged<T: Equatable>(newValue: T, oldValue: T) {
        if newValue != oldValue {
            reloadData()
        }
    }

    func updateSelectAllCheckBox() {
        let indexesCount = currentSelectedIndexes?.count ?? 0
        if indexesCount == sortedData.count, sortedData.count > 0 {
            selectAllCheckBoxHeaderCell?.checked = true
            selectAllCheckBoxHeaderCell?.mixedState = false
        } else if indexesCount > 0 && (indexesCount != 1 || !isRowCreationRow(currentSelectedIndexes?.first ?? -1) ) {
            selectAllCheckBoxHeaderCell?.checked = false
            selectAllCheckBoxHeaderCell?.mixedState = true
        } else {
            selectAllCheckBoxHeaderCell?.checked = false
            selectAllCheckBoxHeaderCell?.mixedState = false
        }
    }

    @objc func contentOffsetDidChange(notification: Notification) {
        if let hovered = hoveredRow,
           let tableView = tableView,
           hovered < sortedData.count,
           let rowView = tableView.rowView(atRow: hovered, makeIfNecessary: false) as? BeamTableRowView {
            rowView.offsetChanged()
            updateCellsVisibility(for: hovered, in: tableView, hovering: false, selected: currentSelectedIndexes?.contains(hovered) == true)
            parent.onHover?(nil, nil)
        }
        hoveredRow = nil
    }

    func headerViewHoveredColumn(column: Int, hovering: Bool) {
        guard column < tableView?.tableColumns.count ?? 0 else { return }
        let tableColumn = tableView?.tableColumns[column]
        if let headerCell = tableColumn?.headerCell as? TableHeaderCell {
            headerCell.isHovering = hovering
        }
        parent.onHover?(nil, nil)
    }

    func tableView(isHovered: Bool) {
        guard let columns = tableView?.tableColumns, !columns.isEmpty else { return }
        let tableColumn = tableView?.tableColumns[0]
        if let headerCell = tableColumn?.headerCell as? TableHeaderCell {
            headerCell.isHovering = isHovered
        }
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
        rowView.onHover = { [weak self, weak tableView] rowView, hovering in
            guard let self = self, let tableView = tableView,
                  let window = tableView.window,
                  rowView.frame.origin.y >= tableView.visibleRect.origin.y else { return }
            let rowFrame = tableView.convert(rowView.frame, to: nil).flippedRectToTopLeftOrigin(in: window)
            self.hoveredRow = hovering ? row : nil
            self.updateCellsVisibility(for: row, in: tableView,
                                       hovering: hovering, selected: self.currentSelectedIndexes?.contains(row) == true)
            if let hoveredRow = self.hoveredRow,
               let originalDataRowIndex = self.getOriginalDataIndexes(for: [hoveredRow]).first {
                self.parent.onHover?(originalDataRowIndex, hovering ? rowFrame : nil)
            } else if hovering {
                self.parent.onHover?(nil, nil)
            }
        }
        if shouldResetScrollOnNextReload, let insets = tableView.enclosingScrollView?.contentView.contentInsets {
            shouldResetScrollOnNextReload = false
            self.tableView?.scroll(CGPoint(x: 0, y: -insets.top))
        }
        return rowView
    }

    private func updateCellsVisibility(for rowIndex: Int, in tableView: NSTableView, hovering: Bool, selected: Bool) {
        guard !isRowCreationRow(rowIndex) else { return }
        if let row = tableView.rowView(atRow: rowIndex, makeIfNecessary: false) {
            parent.columns.enumerated().forEach { index, column in
                guard let cell = row.view(atColumn: index) as? NSTableCellView
                      else { return }
                if column.visibleOnlyOnRowHoverOrSelected {
                    cell.alphaValue = hovering || selected ? 1 : 0
                }
                if var selectableCell = cell as? SelectableTableCellView {
                    selectableCell.isSelected = selected
                }
            }
        }
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
                if isCreationRowLoading {
                    let lottieCell = BeamTableCellLottieView()
                    lottieCell.updateWithLottie(named: "status-update_restart")
                    return lottieCell
                } else {
                    let iconCell = BeamTableCellIconView()
                    let img = NSImage(named: "tool-new")
                    img?.isTemplate = true
                    iconCell.updateWithIcon(img)
                    return iconCell
                }
            } else {
                let textCell = BeamTableCellView()
                textCell.textField?.isEditable = false
                if column.editable {
                    textCell.textField?.placeholderAttributedString = NSAttributedString(string: creationRowTitle ?? "", attributes: [.foregroundColor: BeamColor.Generic.placeholder.nsColor, .font: BeamFont.regular(size: 13).nsFont])
                    textCell.textField?.isEditable = true
                    creationgRowTextField = textCell.textField
                    textCell.textField?.delegate = self
                }
                return textCell
            }
        }
        switch column.type {
        case .CheckBox:
            return setupCheckBoxCell(tableView, at: row, column: column)
        case .Text:
            return setupTextCell(tableView, at: row, column: column)
        case .IconAndText:
            return setupIconAndTextCell(tableView, at: row, column: column)
        case .TwoTextField:
            return setupTwoTextFieldViewCell(tableView, at: row, column: column)
        case .IconButton:
            return setupIconButtonCell(tableView, at: row, column: column)
        }
    }

    private func setupTextCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn) -> BeamTableCellView {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: column.key)
        let textCell: BeamTableCellView

        if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? BeamTableCellView {
            textCell = cell
        } else {
            textCell = BeamTableCellView()
            textCell.identifier = identifier
            let editable = column.editable && !column.isLink
            textCell.textField?.isEditable = editable
            textCell.textField?.font = column.font ?? BeamFont.regular(size: column.fontSize).nsFont
            textCell.textField?.setAccessibilityIdentifier("\(column.title)")
            textCell.textField?.delegate = self
            textCell.isLink = column.isLink
            textCell.foregroundColor = column.foregroundColor
            textCell.selectedForegroundColor = column.selectedForegroundColor
        }

        let item = sortedData[row]
        let value = item.value(forKey: column.key)
        let text = column.stringFromKeyValue(value)
        textCell.setText(text)
        textCell.isSelected = currentSelectedIndexes?.contains(row) == true
        return textCell
    }

    private func setupCheckBoxCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn) -> CheckBoxTableCellView {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: column.key)
        let checkCell: CheckBoxTableCellView

        if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? CheckBoxTableCellView {
            checkCell = cell
        } else {
            checkCell = CheckBoxTableCellView()
            checkCell.identifier = identifier
        }

        checkCell.checked = tableView.selectedRowIndexes.contains(row)
        checkCell.onCheckChange = { [weak tableView] selected in
            if selected {
                tableView?.selectRowIndexes([row], byExtendingSelection: true)
            } else {
                tableView?.deselectRow(row)
            }
        }
        let isSelected = currentSelectedIndexes?.contains(row) == true
        checkCell.alphaValue = column.visibleOnlyOnRowHoverOrSelected && !isSelected ? 0 : 1

        return checkCell
    }

    private func setupIconAndTextCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn)
    -> BeamTableCellIconAndTextView {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: column.key)

        let iconAndTextCell: BeamTableCellIconAndTextView

        if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? BeamTableCellIconAndTextView {
            iconAndTextCell = cell
        } else {
            iconAndTextCell = BeamTableCellIconAndTextView()
            iconAndTextCell.identifier = identifier
            let editable = column.editable && !column.isLink
            iconAndTextCell.textField?.isEditable = editable
            iconAndTextCell.textField?.font = column.font ?? BeamFont.regular(size: column.fontSize).nsFont
            iconAndTextCell.textField?.textColor = column.foregroundColor
            iconAndTextCell.textField?.delegate = self
        }

        let item = sortedData[row] as? IconAndTextTableViewItem
        // Placeholder Image
        let placeholderImage = NSImage(named: "field-web")
        placeholderImage?.isTemplate = true
        iconAndTextCell.updateWithIcon(placeholderImage)
        item?.loadRemoteFavIcon(completion: { favIcon in
            iconAndTextCell.updateWithIcon(favIcon)
        })
        iconAndTextCell.textField?.stringValue = item?.text ?? ""

        return iconAndTextCell
    }

    private func setupTwoTextFieldViewCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn) -> BeamTableCellTwoTextFieldView {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: column.key)

        let twoTextFieldViewCell: BeamTableCellTwoTextFieldView

        if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? BeamTableCellTwoTextFieldView {
            twoTextFieldViewCell = cell
        } else {
            twoTextFieldViewCell = BeamTableCellTwoTextFieldView()
            twoTextFieldViewCell.identifier = identifier
            let editable = column.editable && !column.isLink
            twoTextFieldViewCell.topTextField.isEditable = editable
            twoTextFieldViewCell.botTextField.isEditable = editable
            let font = column.font ?? BeamFont.regular(size: column.fontSize).nsFont
            twoTextFieldViewCell.topTextField.font = font
            twoTextFieldViewCell.botTextField.font = font
            twoTextFieldViewCell.topTextField.textColor = column.foregroundColor
            twoTextFieldViewCell.botTextField.textColor = column.foregroundColor
        }

        let item = sortedData[row] as? TwoTextFieldViewItem

        twoTextFieldViewCell.topTextField.stringValue = item?.topTextFieldValue ?? ""
        twoTextFieldViewCell.botTextField.stringValue = item?.botTextFieldValue ?? ""
        twoTextFieldViewCell.topTextField.placeholderString = item?.topTextFieldPlaceholder
        twoTextFieldViewCell.botTextField.placeholderString = item?.botTextFieldPlaceholder

        return twoTextFieldViewCell
    }

    private func setupIconButtonCell(_ tableView: NSTableView, at row: Int, column: TableViewColumn) -> BeamTableCellIconButtonView? {
        let item = sortedData[row] as? IconButtonTableViewItem

        guard let iconName = item?.iconName, let action = item?.buttonAction else { return nil }

        let identifier = NSUserInterfaceItemIdentifier(rawValue: column.key)
        let iconButtonViewCell: BeamTableCellIconButtonView

        if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? BeamTableCellIconButtonView {
            iconButtonViewCell = cell
        } else {
            iconButtonViewCell = BeamTableCellIconButtonView()
            iconButtonViewCell.identifier = identifier
            iconButtonViewCell.iconButton.contentTintColor = BeamColor.AlphaGray.nsColor
        }

        let iconImage = NSImage(named: iconName)?.fill(color: BeamColor.AlphaGray.nsColor)
        iconImage?.isTemplate = false
        iconButtonViewCell.iconButton.image = iconImage
        iconButtonViewCell.hasPopover = item?.hasPopover ?? false
        iconButtonViewCell.popoverAlignment = item?.popoverAlignment ?? .bottom
        iconButtonViewCell.buttonAction = action
        iconButtonViewCell.iconButton.setAccessibilityIdentifier("\(column.title)-row\(row)")

        return iconButtonViewCell
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
                toUnchecked.forEach { updateCellsVisibility(for: $0, in: tableView,
                                                            hovering: hoveredRow == $0, selected: false) }
            }
            setChecked(true, for: selectedIndexes, in: tableView)
            currentSelectedIndexes = selectedIndexes
            updateSelectAllCheckBox()
            selectedIndexes.forEach { updateCellsVisibility(for: $0, in: tableView,
                                                            hovering: hoveredRow == $0, selected: true) }
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

    func tableViewDidChangeEffectiveAppearance(_ tableView: BeamNSTableView) {
        self.reloadData(soft: true)
    }

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
              let window = tableView.window,
              let originalRow = getOriginalDataIndexes(for: [row]).first,
              column < parent.columns.count
        else { return }
        let columnData = parent.columns[column]
        let location = CGRect(origin: locationInWindow, size: .zero).flippedRectToTopLeftOrigin(in: window).origin
        onRightMouseDown(originalRow, columnData, location)
    }

    func tableView(_ tableView: BeamNSTableView, didDoubleTap row: Int) {
        guard let onDoubleTap = parent.onDoubleTap, let originalRow = getOriginalDataIndexes(for: [row]).first else { return }
        onDoubleTap(originalRow)
    }

}
