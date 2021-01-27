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
    var chevron: CALayer

    init(_ name: String, icon: String = "editor-arrow_right", open: Bool, changed: @escaping (Bool) -> Void = { _ in }) {
        self.changed = changed
        self.open = open
        chevron = Layer.icon(named: icon, color: NSColor.editorIconColor)
        super.init(name, CALayer())
        activated = { [unowned self] in
            self.open.toggle()
            self.changed(self.open)
        }

        self.layer.bounds = chevron.bounds
        self.layer.addSublayer(chevron)

        updateChevron()
    }

    func updateChevron() {
        chevron.setAffineTransform(CGAffineTransform(rotationAngle: open ? CGFloat.pi / 2 : 0))
    }
}
