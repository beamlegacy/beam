//
//  LockButton.swift
//  Beam
//
//  Created by Sebastien Metrot on 10/06/2021.
//

import Foundation

class LockButton: ButtonLayer {
    var locked: Bool = true {
        didSet {
            updateLock()
        }
    }
    var changed: (Bool) -> Void
    var lockedIcon: CALayer
    var unlockedIcon: CALayer

    init(_ name: String, locked: Bool, changed: @escaping (Bool) -> Void = { _ in }) {
        self.changed = changed
        self.locked = locked
        lockedIcon = Layer.icon(named: "status-lock", color: BeamColor.Editor.chevron.nsColor)
        unlockedIcon = Layer.icon(named: "status-unlocked", color: BeamColor.Editor.chevron.nsColor)
        super.init(name, CALayer())
        activated = { [unowned self] in
            self.locked.toggle()
            self.changed(self.locked)
        }

        self.layer.bounds = lockedIcon.bounds
        self.layer.addSublayer(lockedIcon)
        self.layer.addSublayer(unlockedIcon)

        let newActions = [
            kCAOnOrderIn: NSNull(),
            kCAOnOrderOut: NSNull(),
            "sublayers": NSNull(),
            "contents": NSNull(),
            "bounds": NSNull(),
            kCATransition: NSNull()
        ]
        lockedIcon.actions = newActions
        unlockedIcon.actions = newActions

        updateLock()

        setAccessibilityLabel("lock button")
        setAccessibilityRole(.button)
        setAccessibilityDisclosed(locked)
    }

    func updateLock() {
        lockedIcon.isHidden = !locked
        unlockedIcon.isHidden = locked
    }

    override func isAccessibilityDisclosed() -> Bool {
        guard !layer.isHidden else { return false }
        return locked
    }

    override func setAccessibilityDisclosed(_ accessibilityDisclosed: Bool) {
        guard !layer.isHidden, locked else { return }
        locked = accessibilityDisclosed
        self.changed(self.locked)
    }
}
