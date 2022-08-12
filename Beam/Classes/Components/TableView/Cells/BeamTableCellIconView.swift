//
//  BeamTableCellIconView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/05/2022.
//

import Foundation

class BeamTableCellIconView: NSTableCellView {
    private let _iconView: NSImageView

    override var wantsUpdateLayer: Bool { true }

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

    override func updateLayer() {
        if self.effectiveAppearance.isDarkMode {
            _iconView.layer?.compositingFilter = nil
        } else {
            _iconView.layer?.compositingFilter = "multiplyBlendMode"
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

class CustomImageView: NSImageView {

    override var isHighlighted: Bool {
        get { false }
        set { _ = newValue }
    }
}
