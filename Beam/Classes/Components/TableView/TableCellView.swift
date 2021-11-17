//
//  TableCellView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation

private let beamCellHorizontalInset: CGFloat = 10

protocol SelectableTableCellView {
    var isSelected: Bool { get set }
}

class BeamTableCellView: NSTableCellView, SelectableTableCellView {
    var isLink = false
    var isSelected: Bool = false {
        didSet {
            needsLayout = isSelected != oldValue
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

    override init(frame frameRect: NSRect) {
        _textField = NSTextField(frame: frameRect)
        super.init(frame: frameRect)
        _textField.wantsLayer = true
        _textField.backgroundColor = .clear
        _textField.isBordered = false
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

    override func layout() {
        super.layout()
        let color = !isSelected || selectedForegroundColor == nil ? foregroundColor : selectedForegroundColor
        _textField.textColor = color
        if self.effectiveAppearance.isDarkMode {
            _textField.layer?.compositingFilter = nil
        } else {
            _textField.layer?.compositingFilter = "multiplyBlendMode"
        }
    }

    override func updateConstraints() {
        super.updateConstraints()
        let diff = defaultFontBottomBaselineOffset - _textField.baselineOffsetFromBottom
        if diff != 0 {
            // to visually align all textfield that are not the default font size of 13
            // we need to apply the baseline offset difference to the centering constraint
            centerYConstraint?.constant = -diff
        }
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
            tf.attributedStringValue = NSAttributedString(string: tf.stringValue, attributes: [:])
        }
    }

    func shouldHandleMouseDown(at point: CGPoint) -> Bool {
        return isLink && textFieldFrame.contains(point)
    }
}

class BeamTableCellIconView: NSTableCellView {
    private let _iconView: NSImageView
    override init(frame frameRect: NSRect) {
        _iconView = CustomImageView(frame: frameRect)
        super.init(frame: frameRect)
        _iconView.contentTintColor = BeamColor.AlphaGray.nsColor
        _iconView.wantsLayer = true
        _iconView.translatesAutoresizingMaskIntoConstraints = false
        _iconView.isEnabled = true
        self.addSubview(_iconView)
        self.addConstraints([
            centerXAnchor.constraint(equalTo: _iconView.centerXAnchor),
            centerYAnchor.constraint(equalTo: _iconView.centerYAnchor),
            _iconView.widthAnchor.constraint(equalToConstant: 16),
            _iconView.heightAnchor.constraint(equalToConstant: 16)
        ])
        self.textField?.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        if self.effectiveAppearance.isDarkMode {
            _iconView.layer?.compositingFilter = nil
        } else {
            _iconView.layer?.compositingFilter = "multiplyBlendMode"
        }
    }

    func updateWithIcon(_ icon: NSImage?) {
        _iconView.image = icon
    }
}

class CustomImageView: NSImageView {

    override var isHighlighted: Bool {
        get { false }
        set { _ = newValue }
    }
}

class BeamTableCellIconAndTextView: NSTableCellView {
    private let _contentView: NSView
    private let _iconView: NSImageView
    private let _textField: NSTextField

    override init(frame frameRect: NSRect) {
        _contentView = NSView(frame: frameRect)
        _iconView = CustomImageView()
        _textField = NSTextField()
        super.init(frame: frameRect)
        _contentView.translatesAutoresizingMaskIntoConstraints = false

        _textField.backgroundColor = .clear
        _textField.isBordered = false
        _textField.lineBreakMode = .byTruncatingTail
        _textField.translatesAutoresizingMaskIntoConstraints = false
        _textField.font = BeamFont.regular(size: 13).nsFont
        _textField.textColor = BeamColor.Generic.text.nsColor
        _textField.wantsLayer = true

        _iconView.translatesAutoresizingMaskIntoConstraints = false
        _iconView.isEnabled = true

        self.addSubview(_contentView)
        _contentView.addSubview(_iconView)
        _contentView.addSubview(_textField)

        self.addConstraints([
            leadingAnchor.constraint(equalTo: _contentView.leadingAnchor, constant: -beamCellHorizontalInset),
            trailingAnchor.constraint(equalTo: _contentView.trailingAnchor, constant: beamCellHorizontalInset),
            centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            _contentView.heightAnchor.constraint(equalToConstant: 22)
        ])

        self.addConstraints([
            _iconView.leadingAnchor.constraint(equalTo: _contentView.leadingAnchor),
            _iconView.centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            _iconView.widthAnchor.constraint(equalToConstant: 16),
            _iconView.heightAnchor.constraint(equalToConstant: 22),
            _textField.leadingAnchor.constraint(equalTo: _iconView.trailingAnchor, constant: 6),
            _textField.trailingAnchor.constraint(equalTo: _contentView.trailingAnchor),
            _textField.topAnchor.constraint(equalTo: _contentView.topAnchor, constant: 4),
            _textField.heightAnchor.constraint(equalToConstant: 22)

        ])
        self.textField = self._textField
        self.textField?.isHidden = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        if self.effectiveAppearance.isDarkMode {
            _textField.layer?.compositingFilter = nil
        } else {
            _textField.layer?.compositingFilter = "multiplyBlendMode"
        }
    }

    func updateWithIcon(_ icon: NSImage?) {
        _iconView.image = icon
    }
}

class BeamTableCellTwoTextFieldView: NSTableCellView {
    private let _contentView: NSView

    let topTextField: NSTextField
    let botTextField: NSTextField

    override init(frame frameRect: NSRect) {
        _contentView = NSView(frame: frameRect)
        topTextField = NSTextField()
        botTextField = NSTextField()

        super.init(frame: frameRect)

        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        _contentView.translatesAutoresizingMaskIntoConstraints = false

        topTextField.backgroundColor = .clear
        topTextField.isBordered = false
        topTextField.translatesAutoresizingMaskIntoConstraints = false
        topTextField.font = BeamFont.regular(size: 13).nsFont
        topTextField.textColor = BeamColor.Generic.text.nsColor
        topTextField.focusRingType = .none
        topTextField.wantsLayer = true

        botTextField.backgroundColor = .clear
        botTextField.isBordered = false
        botTextField.translatesAutoresizingMaskIntoConstraints = false
        botTextField.font = BeamFont.regular(size: 13).nsFont
        botTextField.textColor = BeamColor.Generic.text.nsColor
        botTextField.focusRingType = .none
        botTextField.wantsLayer = true

        self.addSubview(_contentView)
        _contentView.addSubview(topTextField)
        _contentView.addSubview(botTextField)

        self.addConstraints([
            leadingAnchor.constraint(equalTo: _contentView.leadingAnchor, constant: -beamCellHorizontalInset),
            trailingAnchor.constraint(equalTo: _contentView.trailingAnchor, constant: beamCellHorizontalInset),
            centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            topAnchor.constraint(equalTo: _contentView.topAnchor),
            bottomAnchor.constraint(equalTo: _contentView.bottomAnchor),
            _contentView.heightAnchor.constraint(equalToConstant: 48)
        ])

        self.addConstraints([
            leadingAnchor.constraint(equalTo: topTextField.leadingAnchor, constant: -beamCellHorizontalInset),
            trailingAnchor.constraint(equalTo: topTextField.trailingAnchor, constant: beamCellHorizontalInset),
            leadingAnchor.constraint(equalTo: botTextField.leadingAnchor, constant: -beamCellHorizontalInset),
            trailingAnchor.constraint(equalTo: botTextField.trailingAnchor, constant: beamCellHorizontalInset),
            topTextField.heightAnchor.constraint(equalToConstant: 13),
            botTextField.heightAnchor.constraint(equalToConstant: 13),
            topTextField.topAnchor.constraint(equalTo: _contentView.topAnchor, constant: 8),
            botTextField.topAnchor.constraint(equalTo: topTextField.bottomAnchor, constant: 6)
        ])
        self.textField?.isHidden = false
    }

    override func layout() {
        super.layout()
        if self.effectiveAppearance.isDarkMode {
            topTextField.layer?.compositingFilter = nil
            botTextField.layer?.compositingFilter = nil
        } else {
            topTextField.layer?.compositingFilter = "multiplyBlendMode"
            botTextField.layer?.compositingFilter = "multiplyBlendMode"
        }
    }
}
