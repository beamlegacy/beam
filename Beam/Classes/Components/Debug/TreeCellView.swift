//
//  TreeCellView.swift
//  Beam
//
//  Created by Sébastien Metrot on 09/06/2022.
//

import Foundation
import AppKit

class TreeCellView: NSTableCellView {
    init(_ string: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        field.drawsBackground = false
        field.isBordered = false
        field.isEditable = false
        field.isSelectable = true
        self.addSubview(field)

        textField = field

        self.string = string
        self.frame = field.frame
    }

    var string: String {
        get {
            textField?.stringValue ?? ""
        }
        set {
            textField?.stringValue = newValue
            textField?.sizeToFit()
            if let f = textField?.frame {
                textField?.frame = NSRect(origin: f.origin, size: CGSize(width: f.width, height: 20))
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
