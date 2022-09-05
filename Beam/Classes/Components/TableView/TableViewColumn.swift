//
//  TableViewColumn.swift
//  Beam
//
//  Created by Remi Santos on 31/05/2021.
//

import Foundation

struct TableViewColumn: Equatable {

    enum ColumnType {
        case Text
        case IconAndText
        case CheckBox
        case TwoTextField
        case IconButton
    }

    let key: String
    let title: String
    var type: ColumnType = .Text
    var editable = false
    var isLink = false
    var sortable = true
    var sortableDefaultAscending = false
    var sortableCaseInsensitive = false
    var isInitialSortDescriptor = false
    var resizable = true
    var hidden = false
    var width: CGFloat = 100
    var font: NSFont?
    var fontSize: CGFloat = 13
    var foregroundColor: NSColor = BeamColor.Generic.text.nsColor
    var selectedForegroundColor: NSColor?
    var visibleOnlyOnRowHoverOrSelected = false
    var stringFromKeyValue: ((Any?) -> String) = { value in
        return value as? String ?? ""
    }

    static func == (lhs: TableViewColumn, rhs: TableViewColumn) -> Bool {
        return lhs.key == rhs.key &&
        lhs.title == rhs.title &&
        lhs.type == rhs.type &&
        lhs.editable == rhs.editable &&
        lhs.isLink == rhs.isLink &&
        lhs.sortable == rhs.sortable &&
        lhs.sortableDefaultAscending == rhs.sortableDefaultAscending &&
        lhs.sortableCaseInsensitive == rhs.sortableCaseInsensitive &&
        lhs.isInitialSortDescriptor == rhs.isInitialSortDescriptor &&
        lhs.resizable == rhs.resizable &&
        lhs.hidden == rhs.hidden &&
        lhs.width == rhs.width &&
        lhs.font == rhs.font &&
        lhs.fontSize == rhs.fontSize &&
        lhs.foregroundColor == rhs.foregroundColor &&
        lhs.selectedForegroundColor == rhs.selectedForegroundColor &&
        lhs.visibleOnlyOnRowHoverOrSelected == rhs.visibleOnlyOnRowHoverOrSelected
    }
}
