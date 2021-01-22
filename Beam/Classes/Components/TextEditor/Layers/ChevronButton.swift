//
//  ChevronButton.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/01/2021.
//

import Foundation
import AppKit

class ChevronButton: ButtonLayer {
    var open: Bool = true {
        didSet {
            updateChevron()
        }
    }
    var changed: (Bool) -> Void

    init(_ name: String, icon: String = "editor-arrow_right", open: Bool, changed: @escaping (Bool) -> Void = { _ in }) {
        self.changed = changed
        self.open = open
        super.init(name, Layer.icon(named: icon, color: NSColor.editorIconColor))
        activated = { [unowned self] in
            self.open.toggle()
            self.changed(self.open)
        }

        updateChevron()
    }

    func updateChevron() {
        layer.setAffineTransform(CGAffineTransform(rotationAngle: open ? CGFloat.pi / 2 : 0))
    }
}
