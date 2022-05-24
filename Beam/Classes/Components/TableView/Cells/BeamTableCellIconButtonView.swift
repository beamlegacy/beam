//
//  BeamTableCellIconButtonView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 19/05/2022.
//

import Foundation
import SwiftUI

class BeamTableCellIconButtonView: NSTableCellView {
    private let _contentView: NSView

    let iconButton: NSButton
    var hasPopover: Bool = false
    var popoverAlignment: Edge = .top
    var buttonAction: ((NSPoint?) -> Void)?

    override init(frame frameRect: NSRect) {
        _contentView = NSView(frame: frameRect)
        _contentView.translatesAutoresizingMaskIntoConstraints = false

        iconButton = NSButton()
        iconButton.wantsLayer = true
        iconButton.isBordered = false
        iconButton.bezelStyle = .shadowlessSquare
        iconButton.imagePosition = .imageOnly

        iconButton.layer?.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"

        super.init(frame: frameRect)

        self.iconButton.target = self
        self.iconButton.action = #selector(self.triggerButtonAction)
        iconButton.translatesAutoresizingMaskIntoConstraints = false

        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        _contentView.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(_contentView)
        _contentView.addSubview(iconButton)

        self.addConstraints([
            centerXAnchor.constraint(equalTo: _contentView.centerXAnchor),
            centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            _contentView.widthAnchor.constraint(equalToConstant: 16),
            _contentView.heightAnchor.constraint(equalToConstant: 16)
        ])

        self.addConstraints([
            iconButton.centerXAnchor.constraint(equalTo: _contentView.centerXAnchor),
            iconButton.centerYAnchor.constraint(equalTo: _contentView.centerYAnchor),
            iconButton.widthAnchor.constraint(equalToConstant: 16),
            iconButton.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        iconButton.layer?.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
        let newArea = NSTrackingArea(
            rect: CGRect(origin: _contentView.frame.origin, size: iconButton.frame.size),
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil
        )
        self.addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        let newImage = iconButton.image?.fill(color: BeamColor.Niobium.nsColor)
        iconButton.image = newImage
        newImage?.isTemplate = false
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        let newImage = iconButton.image?.fill(color: BeamColor.AlphaGray.nsColor)
        iconButton.image = newImage
        newImage?.isTemplate = false
    }

    @objc
    func triggerButtonAction() {
        if hasPopover {
            var globalPoint = self.superview?.convert(self.frame.origin, to: nil) ?? self.frame.origin
            if popoverAlignment == .top {
                globalPoint.y += self.frame.height
            }
            if popoverAlignment == .bottom {
                globalPoint.y -= self.frame.height
            }
            buttonAction?(globalPoint)
        }
        buttonAction?(nil)
    }
}
