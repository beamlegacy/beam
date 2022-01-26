//
//  ElementNode+Layers.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

extension ElementNode {

    static var indentLayerPosX: CGFloat = 5

    @objc var shouldDisplayBullet: Bool {
        true
    }
    private static var bulletLayerPositionX = CGFloat(-4)
    @objc var bulletLayerPositionY: CGFloat {
        firstLineBaseline - 14
    }

    @objc var indentLayerPositionY: CGFloat { 3 }

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
        updateIndentLayer()
    }

    private func createDisclosureLayer(at point: NSPoint) {
        guard self as? TextRoot == nil else { return } // no disclosure layer for the root
        let disclosureLayer = ChevronButton(LayerName.disclosure.rawValue, open: open, changed: { [unowned self] value in
            self.open = value
            layers[LayerName.indentLayer.rawValue]?.layer.isHidden = !value
        })
        disclosureLayer.setAccessibilityIdentifier("node_arrow")
        addLayer(disclosureLayer, origin: point)
        updateDisclosureLayer()
    }

    private func createBulletPointLayer(at point: NSPoint) {
        guard shouldDisplayBullet else { return }
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
        if bulletLayer.frame.origin.y != bulletLayerPositionY {
            bulletLayer.frame.origin = CGPoint(x: Self.bulletLayerPositionX, y: bulletLayerPositionY)
        }
        bulletLayer.layer.opacity = Float((showDisclosureButton || !PreferencesManager.alwaysShowBullets) ? 0 : 1)
        bulletLayer.layer.isHidden = !self.isFocused && self.elementText.isEmpty
    }

    private func updateDisclosureLayer() {
        guard let disclosureLayer = self.layers[LayerName.disclosure.rawValue] as? ChevronButton else { return }
        if disclosureLayer.frame.origin.y != bulletLayerPositionY {
            disclosureLayer.frame.origin = CGPoint(x: Self.bulletLayerPositionX, y: bulletLayerPositionY)
        }

        disclosureLayer.layer.isHidden = !showDisclosureButton
    }

    private func updateIndentLayer() {
        guard let indentLayer = layers[LayerName.indentLayer.rawValue] else { return }
        let y = firstLineHeight + indentLayerPositionY
        indentLayer.frame = NSRect(x: Self.indentLayerPosX, y: y - 4, width: 0.5, height: frame.height - y)
        indentLayer.layer.isHidden = !(showDisclosureButton && self.open)
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
