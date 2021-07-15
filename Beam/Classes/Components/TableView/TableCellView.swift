//
//  TableCellView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation

class BeamTableCellView: NSTableCellView {
    var isLink = false

    private let _textField: NSTextField
    private var textFieldFrame: NSRect {
        let tf = _textField
        return CGRect(origin: tf.frame.origin, size: tf.sizeThatFits(bounds.size))
    }
    override init(frame frameRect: NSRect) {
        _textField = NSTextField(frame: frameRect)
        super.init(frame: frameRect)
        _textField.backgroundColor = .clear
        _textField.isBordered = false
        _textField.translatesAutoresizingMaskIntoConstraints = false
        _textField.font = BeamFont.regular(size: 13).nsFont
        _textField.textColor = BeamColor.Generic.text.nsColor
        _textField.focusRingType = .none
        self.addSubview(_textField)
        self.addConstraints([
            leadingAnchor.constraint(equalTo: _textField.leadingAnchor),
            trailingAnchor.constraint(equalTo: _textField.trailingAnchor),
            centerYAnchor.constraint(equalTo: _textField.centerYAnchor),
            _textField.heightAnchor.constraint(equalToConstant: 16)
        ])
        self.textField = self._textField
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        _iconView.contentTintColor = BeamColor.LightStoneGray.nsColor

        _iconView.translatesAutoresizingMaskIntoConstraints = false
        _iconView.isEnabled = true
        _iconView.appearance = NSAppearance(named: .vibrantDark)
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
        _textField.translatesAutoresizingMaskIntoConstraints = false
        _textField.font = BeamFont.regular(size: 13).nsFont
        _textField.textColor = BeamColor.Generic.text.nsColor

        _iconView.translatesAutoresizingMaskIntoConstraints = false
        _iconView.isEnabled = true

        self.addSubview(_contentView)
        _contentView.addSubview(_iconView)
        _contentView.addSubview(_textField)

        self.addConstraints([
            leadingAnchor.constraint(equalTo: _contentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: _contentView.trailingAnchor),
            centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            _contentView.heightAnchor.constraint(equalToConstant: 22)
        ])

        self.addConstraints([
            _iconView.leadingAnchor.constraint(equalTo: _contentView.leadingAnchor),
            _iconView.centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            _iconView.widthAnchor.constraint(equalToConstant: 16),
            _iconView.heightAnchor.constraint(equalToConstant: 16),
            _textField.leadingAnchor.constraint(equalTo: _iconView.trailingAnchor, constant: 6),
            _textField.trailingAnchor.constraint(equalTo: _contentView.trailingAnchor),
            _textField.centerYAnchor.constraint(equalTo: _contentView.centerYAnchor)
        ])
        self.textField = self._textField
        self.textField?.isHidden = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        _contentView.translatesAutoresizingMaskIntoConstraints = false

        topTextField.backgroundColor = .clear
        topTextField.isBordered = false
        topTextField.translatesAutoresizingMaskIntoConstraints = false
        topTextField.font = BeamFont.regular(size: 13).nsFont
        topTextField.textColor = BeamColor.Generic.text.nsColor
        topTextField.focusRingType = .none

        botTextField.backgroundColor = .clear
        botTextField.isBordered = false
        botTextField.translatesAutoresizingMaskIntoConstraints = false
        botTextField.font = BeamFont.regular(size: 13).nsFont
        botTextField.textColor = BeamColor.Generic.text.nsColor
        botTextField.focusRingType = .none

        self.addSubview(_contentView)
        _contentView.addSubview(topTextField)
        _contentView.addSubview(botTextField)

        self.addConstraints([
            leadingAnchor.constraint(equalTo: _contentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: _contentView.trailingAnchor),
            centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            topAnchor.constraint(equalTo: _contentView.topAnchor),
            bottomAnchor.constraint(equalTo: _contentView.bottomAnchor),
            _contentView.heightAnchor.constraint(equalToConstant: 48)
        ])

        self.addConstraints([
            leadingAnchor.constraint(equalTo: topTextField.leadingAnchor),
            trailingAnchor.constraint(equalTo: topTextField.trailingAnchor),
            leadingAnchor.constraint(equalTo: botTextField.leadingAnchor),
            trailingAnchor.constraint(equalTo: botTextField.trailingAnchor),
            topTextField.heightAnchor.constraint(equalToConstant: 13),
            botTextField.heightAnchor.constraint(equalToConstant: 13),
            topTextField.topAnchor.constraint(equalTo: _contentView.topAnchor, constant: 8),
            botTextField.topAnchor.constraint(equalTo: topTextField.bottomAnchor, constant: 6)
        ])
        self.textField?.isHidden = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
