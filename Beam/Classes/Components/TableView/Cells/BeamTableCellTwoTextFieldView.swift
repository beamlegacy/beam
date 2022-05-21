//
//  BeamTableCellTwoTextFieldView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/05/2022.
//

import Foundation

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
