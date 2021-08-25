//
//  ElementNode+Layers.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

extension ElementNode {

    private static var bulletLayerPositionX = CGFloat(-4)
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
        indentLayer.actions = [
            "opacity": opacityAnimation
        ]
        addLayer(Layer(name: LayerName.indentLayer.rawValue, layer: indentLayer))
        updateIndentLayer()
    }

    private func createDisclosureLayer(at point: NSPoint) {
        let disclosureLayer = ChevronButton(LayerName.disclosure.rawValue, open: open, changed: { [unowned self] value in
            self.open = value
            layers[LayerName.indentLayer.rawValue]?.layer.isHidden = !value
        })
        disclosureLayer.layer.actions = [
            "opacity": opacityAnimation
        ]
        addLayer(disclosureLayer, origin: point)
        updateDisclosureLayer()
    }

    private func createBulletPointLayer(at point: NSPoint) {
        let bulletLayer = Layer(name: LayerName.bullet.rawValue,
                                layer: Layer.icon(named: "editor-bullet", color: BeamColor.Editor.bullet.nsColor))
        bulletLayer.layer.actions = [
            "opacity": opacityAnimation
        ]

        addLayer(bulletLayer, origin: point)
        updateBulletLayer()
    }

    var opacityAnimation: CABasicAnimation {
        let anim = CABasicAnimation()
        anim.duration = 0.3
        return anim
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

        bulletLayer.layer.opacity = Float((showDisclosureButton || !PreferencesManager.alwaysShowBullets) ? 0 : 1)
    }

    private func updateDisclosureLayer() {
        guard let disclosureLayer = self.layers[LayerName.disclosure.rawValue] as? ChevronButton else { return }

        let show = showDisclosureButton && (PreferencesManager.alwaysShowBullets || hover)
        disclosureLayer.layer.opacity = Float(show ? 1 : 0)
    }

    private func updateIndentLayer() {
        guard let indentLayer = layers[LayerName.indentLayer.rawValue] else { return }
        let y = firstLineHeight + 8
        indentLayer.frame = NSRect(x: 4.5, y: y - 5, width: 1, height: frame.height - y - 5)
        let show = (showDisclosureButton && (PreferencesManager.alwaysShowBullets || hover))  && self.open
        indentLayer.layer.opacity = Float(show ? 1 : 0)
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
        layer?.frame = NSRect(x: 20, y: 3, width: 14, height: 14)
        layer?.isChecked = checked
        layer?.layer.isHidden = hidden
    }
}
