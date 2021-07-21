//
//  ElementNode+Layers.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

extension ElementNode {

    private static var bulletLayerPositionX = CGFloat(14)

    private enum LayerName: String {
        case indentLayer
        case bullet
        case disclosure
        case checkbox
    }

    // MARK: - Create Layers
    func createElementLayers() {
        createIndentLayer()
        var posY = isHeader ? firstLineBaseline - 8 : firstLineBaseline - 13
        if self as? EmbedNode != nil {
            posY = 9
        }
        let bulletPoint = NSPoint(x: Self.bulletLayerPositionX, y: posY)
        createDisclosureLayer(at: bulletPoint)
        createBulletPointLayer(at: bulletPoint)
    }

    private func createIndentLayer() {
        let indentLayer = CALayer()
        indentLayer.backgroundColor = BeamColor.Editor.indentBackground.cgColor
        indentLayer.enableAnimations = false
        addLayer(Layer(name: LayerName.indentLayer.rawValue, layer: indentLayer))
        updateIndentLayer()
    }

    private func createDisclosureLayer(at point: NSPoint) {
        let disclosureLayer = ChevronButton(LayerName.disclosure.rawValue, open: open, changed: { [unowned self] value in
            self.open = value
            layers[LayerName.indentLayer.rawValue]?.layer.isHidden = !value
        })
        addLayer(disclosureLayer, origin: point)
    }

    private func createBulletPointLayer(at point: NSPoint) {
        let bulletLayer = Layer(name: LayerName.bullet.rawValue,
                                layer: Layer.icon(named: "editor-bullet", color: BeamColor.Editor.bullet.nsColor))
        bulletLayer.layer.isHidden = true
        addLayer(bulletLayer, origin: point)
    }

    @discardableResult
    private func createCheckboxLayer(at point: NSPoint) -> CheckboxLayer? {
        guard let textNode = self as? TextNode else { return nil }
        let checkboxLayer = CheckboxLayer(name: LayerName.checkbox.rawValue) { [weak self] checked in
            self?.cmdManager.formatText(in: textNode, for: .check(checked), with: nil, for: nil, isActive: false)
        }
        checkboxLayer.layer.isHidden = true
        addLayer(checkboxLayer, origin: point)
        return checkboxLayer
    }

    // MARK: - Update Layers
    func updateElementLayers() {
        updateBulletLayer()
        updateDisclosureLayer()
        updateIndentLayer()
        updateCheckboxLayer()
    }

    private func updateBulletLayer() {
        guard let bulletLayer = self.layers[LayerName.bullet.rawValue] else { return }

        if showDisclosureButton || !PreferencesManager.alwaysShowBullets {
            bulletLayer.layer.isHidden = true
        } else if PreferencesManager.alwaysShowBullets {
            bulletLayer.layer.isHidden = false
        }
    }

    private func updateDisclosureLayer() {
        guard let disclosureLayer = self.layers[LayerName.disclosure.rawValue] as? ChevronButton else { return }

        if showDisclosureButton && PreferencesManager.alwaysShowBullets || !open {
            disclosureLayer.layer.isHidden = false
        } else if showDisclosureButton && !PreferencesManager.alwaysShowBullets {
            disclosureLayer.layer.opacity = 0
        } else if !showDisclosureButton {
            disclosureLayer.layer.isHidden = true
        }
    }

    private func updateIndentLayer() {
        guard let indentLayer = layers[LayerName.indentLayer.rawValue] else { return }
        let y = firstLineHeight + 8
        indentLayer.frame = NSRect(x: childInset + 4.5, y: y - 5, width: 1, height: frame.height - y - 5)
        indentLayer.layer.isHidden = children.isEmpty || !open
        indentLayer.layer.opacity = 0
    }

    internal func handle(hover: Bool) {
        guard let disclosureLayer = self.layers[LayerName.disclosure.rawValue] as? ChevronButton else { return }
        guard let indentLayer = layers[LayerName.indentLayer.rawValue] else { return }

        if open {
            if hover && disclosureLayer.layer.opacity == 0 && indentLayer.layer.opacity == 0 {
                let fadeIn = CABasicAnimation(keyPath: "opacity")
                fadeIn.fromValue = 0
                fadeIn.toValue = 1
                fadeIn.duration = 0.1
                fadeIn.timingFunction = CAMediaTimingFunction(name: .easeIn)
                disclosureLayer.layer.add(fadeIn, forKey: "disclosureFadeIn")
                indentLayer.layer.add(fadeIn, forKey: "indentFadeIn")
                disclosureLayer.layer.opacity = 1
                indentLayer.layer.opacity = 1
            } else if !hover && disclosureLayer.layer.opacity == 1 && indentLayer.layer.opacity == 1 {
                let fadeOut = CABasicAnimation(keyPath: "opacity")
                fadeOut.fromValue = 1
                fadeOut.toValue = 0
                fadeOut.duration = 0.1
                fadeOut.timingFunction = CAMediaTimingFunction(name: .easeOut)
                disclosureLayer.layer.add(fadeOut, forKey: "disclosureFadeOut")
                indentLayer.layer.add(fadeOut, forKey: "indentFadeOut")
                disclosureLayer.layer.opacity = 0
                indentLayer.layer.opacity = 0
            }
        }
    }

    private func updateCheckboxLayer() {
        var checked = false
        var hidden = true
        if case .check(let on) = elementKind {
            hidden = false
            checked = on
        }
        var layer = layers[LayerName.checkbox.rawValue] as? CheckboxLayer
        guard !hidden else {
            if let l = layer {
                removeLayer(l)
            }
            return
        }
        if layer == nil {
            layer = createCheckboxLayer(at: layers[LayerName.bullet.rawValue]?.frame.origin ?? .zero)
        }
        layer?.frame = NSRect(x: childInset + 20, y: 3, width: 14, height: 14)
        layer?.isChecked = checked
        layer?.layer.isHidden = hidden
    }

}
