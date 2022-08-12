//
//  BeamTableCellView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation
import SwiftUI

let beamCellHorizontalInset: CGFloat = 10

protocol SelectableTableCellView {
    var isSelected: Bool { get set }
}

class BeamTableCellView: NSTableCellView, SelectableTableCellView {
    var isLink = false
    var isSelected: Bool = false {
        didSet {
            needsDisplay = isSelected != oldValue
        }
    }

    var foregroundColor: NSColor = BeamColor.Generic.text.nsColor
    var selectedForegroundColor: NSColor?

    private let _textField: NSTextField
    private var textFieldFrame: NSRect {
        let tf = _textField
        return CGRect(origin: tf.frame.origin, size: tf.sizeThatFits(bounds.size))
    }
    private var centerYConstraint: NSLayoutConstraint?
    private var defaultFontBottomBaselineOffset: CGFloat = 3

    override var wantsUpdateLayer: Bool { true }

    override init(frame frameRect: NSRect) {
        _textField = NSTextField(frame: frameRect)
        super.init(frame: frameRect)
        _textField.wantsLayer = true
        _textField.backgroundColor = .clear
        _textField.isBordered = false
        _textField.maximumNumberOfLines = 1
        _textField.cell?.truncatesLastVisibleLine = true
        _textField.translatesAutoresizingMaskIntoConstraints = false
        _textField.font = BeamFont.regular(size: 13).nsFont
        defaultFontBottomBaselineOffset = _textField.baselineOffsetFromBottom
        _textField.focusRingType = .none
        self.addSubview(_textField)
        let centerYConstraint = centerYAnchor.constraint(equalTo: _textField.centerYAnchor)
        self.centerYConstraint = centerYConstraint
        self.addConstraints([
            leadingAnchor.constraint(equalTo: _textField.leadingAnchor, constant: -beamCellHorizontalInset),
            trailingAnchor.constraint(equalTo: _textField.trailingAnchor, constant: beamCellHorizontalInset),
            centerYConstraint
        ])
        self.textField = self._textField
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        let color = !isSelected || selectedForegroundColor == nil ? foregroundColor : selectedForegroundColor
        _textField.textColor = color
        if self.effectiveAppearance.isDarkMode {
            _textField.layer?.compositingFilter = nil
        } else {
            _textField.layer?.compositingFilter = "multiplyBlendMode"
        }
    }

    override func updateConstraints() {
        let diff = defaultFontBottomBaselineOffset - _textField.baselineOffsetFromBottom
        if diff != 0 {
            // to visually align all textfield that are not the default font size of 13
            // we need to apply the baseline offset difference to the centering constraint
            centerYConstraint?.constant = -diff
        }
        super.updateConstraints()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard isLink else { return }
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        let newArea = NSTrackingArea(
            rect: textFieldFrame,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil
        )
        self.addTrackingArea(newArea)
    }

    func setText(_ text: String) {
        textField?.stringValue = text
        if isLink {
            textField?.attributedStringValue = NSAttributedString(string: text, attributes: [:])
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let tf = textField, isLink {
            tf.attributedStringValue = NSAttributedString(string: tf.stringValue, attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: tf.textColor ?? BeamColor.Generic.text.nsColor,
                .cursor: NSCursor.pointingHand
            ])
            NSCursor.pointingHand.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let tf = textField, isLink {
            setText(tf.stringValue)
        }
    }

    func shouldHandleMouseDown(at point: CGPoint) -> Bool {
        return isLink && textFieldFrame.contains(point)
    }
}
