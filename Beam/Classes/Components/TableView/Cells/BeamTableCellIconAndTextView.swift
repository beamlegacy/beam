//
//  BeamTableCellIconAndTextView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/05/2022.
//

import Foundation

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

        _iconView.contentTintColor = BeamColor.LightStoneGray.nsColor
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

    override var backgroundStyle: NSView.BackgroundStyle {
        get { .normal }
        set { _ = newValue }
    }
}
