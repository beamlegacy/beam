//
//  CheckBoxTableCellView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation

class CheckBoxTableCellView: NSTableCellView {
    private var checkBoxLayer: BeamCheckboxCALayer
    private var isHovering = false {
        didSet {
            checkBoxLayer.isHovering = isHovering
        }
    }
    var checked: Bool {
        get { checkBoxLayer.isChecked }
        set { checkBoxLayer.isChecked = newValue }
    }
    var onCheckChange: ((Bool) -> Void)?

    override var wantsUpdateLayer: Bool { true }

    override init(frame frameRect: NSRect) {
        checkBoxLayer = BeamCheckboxCALayer()
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.addSublayer(checkBoxLayer)
    }

    override func updateLayer() {
        var frame = checkBoxLayer.bounds
        frame.origin = CGPoint(x: (bounds.width - frame.width) / 2, y: (bounds.height - frame.height) / 2)
        checkBoxLayer.frame = frame
        if self.effectiveAppearance.isDarkMode {
            checkBoxLayer.compositingFilter = nil
        } else {
            checkBoxLayer.compositingFilter = "multiplyBlendMode"
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func onCheck(value: Bool) {
        onCheckChange?(value)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil
        )
        self.addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        checkBoxLayer.setNeedsLayout()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        checkBoxLayer.setNeedsLayout()
    }
}

class CheckBoxTableHeaderCell: TableHeaderCell {
    var checked: Bool {
        get { checkBoxLayer.isChecked }
        set { checkBoxLayer.isChecked = newValue }
    }
    var mixedState: Bool {
        get { checkBoxLayer.isMixedState }
        set { checkBoxLayer.isMixedState = newValue }
    }
    private var checkBoxLayer: BeamCheckboxCALayer

    override var isHovering: Bool {
        didSet {
            checkBoxLayer.isHidden = !isHovering
            checkBoxLayer.isHovering = isHovering
            checkBoxLayer.setNeedsLayout()
        }
    }

    init(textCell: String) {
        checkBoxLayer = BeamCheckboxCALayer()
        checkBoxLayer.isHidden = true
        super.init(textCell: textCell)

        drawsBottomBorder = false
        drawsTrailingBorder = false
        contentLeadingInset = 5.5
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        if checkBoxLayer.superlayer != controlView.layer {
            controlView.layer?.addSublayer(checkBoxLayer)
        }
        let checkFrame = cellFrame.insetBy(dx: 0, dy: 0.5)
        checkBoxLayer.frame = checkFrame
    }
}
