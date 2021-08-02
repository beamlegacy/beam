//
//  ElementNode+Layers.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

extension ElementNode {

    private static var bulletLayerPositionX = CGFloat(14)
    @objc var bulletLayerPositionY: CGFloat {
        isHeader ? firstLineBaseline - 8 : firstLineBaseline - 13
    }
    private enum LayerName: String {
        case indentLayer
        case bullet
        case disclosure
        case checkbox
    }

    // MARK: - Create Layers
    func createElementLayers() {
        createIndentLayer()
        let bulletPoint = NSPoint(x: Self.bulletLayerPositionX, y: bulletLayerPositionY)
        createDisclosureLayer(at: bulletPoint)
        createBulletPointLayer(at: bulletPoint)
    }

    private func createIndentLayer() {
        let indentLayer = CALayer()
        indentLayer.backgroundColor = BeamColor.Editor.indentBackground.cgColor
        indentLayer.enableAnimations = false
        addLayer(Layer(name: LayerName.indentLayer.rawValue, layer: indentLayer))
        updateIndentLayer(with: PreferencesManager.alwaysShowBullets ? 1 : 0)
    }

    private func createDisclosureLayer(at point: NSPoint) {
        let disclosureLayer = ChevronButton(LayerName.disclosure.rawValue, open: open, changed: { [unowned self] value in
            self.open = value
            layers[LayerName.indentLayer.rawValue]?.layer.isHidden = !value
        })
        addLayer(disclosureLayer, origin: point)
        updateDisclosureLayer(alwaysShowBullets: PreferencesManager.alwaysShowBullets, with: PreferencesManager.alwaysShowBullets ? 1 : 0)
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
        updateBulletLayer(alwaysShowBullets: PreferencesManager.alwaysShowBullets)
        updateDisclosureLayer(alwaysShowBullets: PreferencesManager.alwaysShowBullets)
        updateIndentLayer(with: PreferencesManager.alwaysShowBullets ? 1 : 0)
        updateCheckboxLayer()
    }

    func alwaysShowLayers(isOn: Bool) {
        updateBulletLayer(alwaysShowBullets: isOn)
        updateDisclosureLayer(alwaysShowBullets: isOn, with: isOn ? 1 : 0)
        updateIndentLayer(with: isOn ? 1 : 0)
    }

    private func updateBulletLayer(alwaysShowBullets: Bool) {
        guard let bulletLayer = self.layers[LayerName.bullet.rawValue] else { return }

        if showDisclosureButton || !alwaysShowBullets {
            bulletLayer.layer.isHidden = true
        } else if alwaysShowBullets {
            bulletLayer.layer.isHidden = false
        }
    }

    private func updateDisclosureLayer(alwaysShowBullets: Bool, with opacity: Float? = nil) {
        guard let disclosureLayer = self.layers[LayerName.disclosure.rawValue] as? ChevronButton else { return }

        if let opacityValue = opacity {
            disclosureLayer.layer.opacity = opacityValue
        }
        if showDisclosureButton && alwaysShowBullets {
            disclosureLayer.layer.isHidden = false
        } else if showDisclosureButton && !alwaysShowBullets {
            disclosureLayer.layer.isHidden = false
            disclosureLayer.layer.opacity = open ? 0 : 1
        } else if !showDisclosureButton {
            disclosureLayer.layer.isHidden = true
        }
    }

    private func updateIndentLayer(with opacity: Float? = nil) {
        guard let indentLayer = layers[LayerName.indentLayer.rawValue] else { return }
        let y = firstLineHeight + 8
        indentLayer.frame = NSRect(x: childInset + 4.5, y: y - 5, width: 1, height: frame.height - y - 5)
        indentLayer.layer.isHidden = children.isEmpty || !open
        if let opacityValue = opacity {
            indentLayer.layer.opacity = opacityValue
        }
    }

    internal func handle(hover: Bool) {
        guard let disclosureLayer = layers[LayerName.disclosure.rawValue] else { return }
        guard let indentLayer = layers[LayerName.indentLayer.rawValue] else { return }
        if open {
            if hover && disclosureLayer.layer.opacity == 0 && indentLayer.layer.opacity == 0 ||
                !hover && disclosureLayer.layer.opacity == 1 && indentLayer.layer.opacity == 1 {
                let oldValue = disclosureLayer.layer.opacity
                let newValue: Float = oldValue == 0 ? 1 : 0
                let opacityAnimation = CABasicAnimation(keyPath: "opacity")
                opacityAnimation.fromValue = oldValue
                opacityAnimation.toValue = newValue
                opacityAnimation.duration = 0.3
                disclosureLayer.layer.add(opacityAnimation, forKey: "disclosureOpacity")
                indentLayer.layer.add(opacityAnimation, forKey: "indentOpacity")
                disclosureLayer.layer.opacity = newValue
                indentLayer.layer.opacity = newValue
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
