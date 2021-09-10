//
//  TableViewColumn.swift
//  Beam
//
//  Created by Remi Santos on 31/05/2021.
//

import Foundation

struct TableViewColumn {

    enum ColumnType {
        case Text
        case IconAndText
        case CheckBox
        case TwoTextField
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
    var width: CGFloat = 100
    var font: NSFont?
    var fontSize: CGFloat = 13
    var fontColor: NSColor = BeamColor.Generic.text.nsColor
    var visibleOnlyOnRowHoverOrSelected = false
    var stringFromKeyValue: ((Any?) -> String) = { value in
        return value as? String ?? ""
    }
}
