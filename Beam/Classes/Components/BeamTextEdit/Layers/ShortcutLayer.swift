//
//  ShortcutLayer.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 08/04/2021.
//

import Foundation

class ShortcutLayer: Layer {
    var activated: (Bool) -> Void
    var text: String
    var textLayer: CATextLayer?
    var icons: [String]
    var iconsLayer: [CALayer] = []
    var iconSpacing: CGFloat = 3.5
    var textSpacing: CGFloat = 5

    init(name: String, text: String, icons: [String], activated: @escaping (Bool) -> Void = { _ in }) {
        self.text = text
        self.icons = icons
        self.activated = activated
        super.init(name: name, layer: CALayer())
        setupIcons()
        setupText()
        setupBounds()

        mouseUp = { [unowned self] info -> Bool in
            let p = layer.contains(info.position)
            if p {
                self.activated(true)
            }
            return true
        }
        mouseDown = { [unowned self] _ -> Bool in
            handleMouseDown()
            return true
        }
    }

    override func handleHover(_ value: Bool) {
        for iconLayer in iconsLayer {
            iconLayer.backgroundColor = value ? BeamColor.Editor.searchHover.cgColor : BeamColor.Editor.searchNormal.cgColor
        }
        guard let textLayer = self.textLayer, let lastIcon = iconsLayer.last else { return }
        textLayer.isHidden = value ? false : true
        textLayer.setAffineTransform(value ? CGAffineTransform(translationX: lastIcon.frame.origin.x + lastIcon.frame.width, y: 0) : CGAffineTransform.identity)
        textLayer.foregroundColor = value ? BeamColor.Editor.searchHover.cgColor : BeamColor.Editor.searchNormal.cgColor
    }

    private func handleMouseDown() {
        self.textLayer?.foregroundColor = BeamColor.Editor.searchClicked.cgColor
        for iconLayer in iconsLayer {
            iconLayer.backgroundColor = BeamColor.Editor.searchClicked.cgColor
        }
    }

    private func setupIcons() {
        var posX: CGFloat = 0
        for icon in icons {
            let iconLayer = Layer.icon(named: icon, color: BeamColor.Editor.searchNormal.nsColor)
            iconLayer.frame.origin.x = posX
            iconLayer.frame.origin.y = 2
            posX += iconLayer.frame.width + iconSpacing
            iconsLayer.append(iconLayer)
            self.layer.addSublayer(iconLayer)
        }
    }

    private func setupText() {
        let posX: CGFloat = textSpacing
        let textLayer = Layer.text(text, color: BeamColor.Editor.searchNormal.nsColor)
        textLayer.font = BeamFont.medium(size: 12).nsFont
        textLayer.frame.origin.x = posX
        textLayer.isHidden = true
        self.textLayer = textLayer
        self.layer.addSublayer(textLayer)
    }

    private func setupBounds() {
        var rect = NSRect()
        rect.origin = CGPoint.zero
        var width: CGFloat = 0
        for iconLayer in iconsLayer {
            width += iconLayer.frame.width
        }
        width += iconSpacing * CGFloat((iconsLayer.count - 1))
        width += textSpacing + (textLayer?.frame.width ?? 0)
        rect.size = CGSize(width: width, height: 20)
        self.layer.bounds = rect
    }
}
