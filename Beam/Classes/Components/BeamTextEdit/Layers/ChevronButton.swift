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
        chevron = Layer.icon(named: icon, color: BeamColor.Editor.chevron.nsColor)
        super.init(name, CALayer())
        activated = { [unowned self] in
            self.open.toggle()
            self.changed(self.open)
        }

        self.layer.bounds = chevron.bounds
        self.layer.addSublayer(chevron)
        self.layer.actions = [
            "opacity": NSNull()
        ]
        updateChevron()

        setAccessibilityRole(.disclosureTriangle)
        setAccessibilityDisclosed(open)
    }

    func updateChevron() {
        chevron.setAffineTransform(CGAffineTransform(rotationAngle: open ? CGFloat.pi / 2 : 0))
        setAccessibilityLabel("disclosure triangle \(open ? "opened" : "closed")")
    }

    override func isAccessibilityDisclosed() -> Bool {
        guard !layer.isHidden else { return false }
        return open
    }

    override func setAccessibilityDisclosed(_ accessibilityDisclosed: Bool) {
        guard !layer.isHidden, open else { return }
        open = accessibilityDisclosed
        self.changed(self.open)
    }
}
