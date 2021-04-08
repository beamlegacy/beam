//
//  TableCellView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation

class BeamTableCellView: NSTableCellView {
    private let _textField: NSTextField
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
        set {

        }
        get {
            return false
        }
    }
}
