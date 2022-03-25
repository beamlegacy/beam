//
//  ElementNode+Layers.swift
//  Beam
//
//  Created by Remi Santos on 22/06/2021.
//

import Foundation

extension ElementNode {

    static var indentLayerPositionX: CGFloat = 5
    @objc var indentLayerPositionY: CGFloat { 3 }

    @objc var shouldDisplayBullet: Bool {
        true
    }
    private static var bulletLayerPositionX = CGFloat(-4)
    @objc var bulletLayerPositionY: CGFloat {
        firstLineBaseline - 14
    }

    var showMoveHandle: Bool {
        cursorHoverBulletPoint || cursorHoverMoveHandle
    }

    private var moveHandlePosition: CGPoint {
        CGPoint(x: Self.bulletLayerPositionX - childInset * CGFloat(depth), y: bulletLayerPositionY)
    }

    private enum LayerName: String {
        case indentLayer
        case bullet
        case disclosure
        case checkbox
        case moveHandle
        case moveShadow
    }

    // MARK: - Create Layers
    func createElementLayers() {
        createIndentLayer()
        let bulletPoint = CGPoint(x: Self.bulletLayerPositionX, y: bulletLayerPositionY)
        createDisclosureLayer(at: bulletPoint)
        createBulletPointLayer(at: bulletPoint)

        createMoveHandleLayer(at: moveHandlePosition)
        let shadowOrigin = CGPoint(x: moveHandlePosition.x, y: moveHandlePosition.y - 6)
        createMoveShadowLayer(at: shadowOrigin)
    }

    private func createIndentLayer() {
        let indentLayer = CALayer()
        indentLayer.enableAnimations = false
        addLayer(Layer(name: LayerName.indentLayer.rawValue, layer: indentLayer))
        updateIndentLayer()
    }

    private func createDisclosureLayer(at point: CGPoint) {
        guard self as? TextRoot == nil else { return } // no disclosure layer for the root
        let disclosureLayer = ChevronButton(LayerName.disclosure.rawValue, open: open, changed: { [unowned self] value in
            self.open = value
            layers[LayerName.indentLayer.rawValue]?.layer.isHidden = !value
        })
        disclosureLayer.setAccessibilityIdentifier("node_arrow")
        addLayer(disclosureLayer, origin: point)
        updateDisclosureLayer()
    }

    private func createBulletPointLayer(at point: CGPoint) {
        guard shouldDisplayBullet else { return }
        let bulletLayer = Layer(name: LayerName.bullet.rawValue, layer: Layer.icon(named: "editor-bullet"))
        bulletLayer.layer.actions = [
            "opacity": opacityAnimation
        ]

        bulletLayer.hovered = { [weak self] hover in
            self?.cursorHoverBulletPoint = hover
        }

        addLayer(bulletLayer, origin: point)
        updateBulletLayer()
    }

    private func createMoveHandleLayer(at point: CGPoint) {
        guard self as? TextRoot == nil, self as? ProxyNode == nil else { return } // no move handle layer for the root or proxies
        let moveLayer = Layer(name: LayerName.moveHandle.rawValue, layer: Layer.icon(named: "editor-handle"))
        moveLayer.layer.actions = [
            "opacity": opacityAnimation
        ]
        moveLayer.cursor = .openHand
        moveLayer.layer.masksToBounds = false

        moveLayer.layer.backgroundColor = BeamColor.Editor.bullet.cgColor

        moveLayer.mouseDown = { [weak self] mouseInfo in
            guard let self = self else { return false }
            guard let moveLayer = self.layers[LayerName.moveHandle.rawValue] else { return false }
            guard let editor = self.editor, editor.widgetDidStartMoving(self, at: mouseInfo.globalPosition) else { return false }
            moveLayer.cursor = .closedHand
            return true
        }

        moveLayer.mouseUp = { [weak self] mouseInfo in
            guard let self = self else { return false }
            guard let moveLayer = self.layers[LayerName.moveHandle.rawValue] else { return false }

            self.editor?.widgetDidStopMoving(self, at: mouseInfo.globalPosition)

            let cursor = NSCursor.openHand
            moveLayer.cursor = cursor
            self.editor?.mouseCursorManager.setMouseCursor(cursor: cursor)
            return true
        }

        moveLayer.hovered = { [weak self] hover in
            self?.cursorHoverMoveHandle = hover
        }

        moveLayer.mouseDragged = { [weak self] mouseInfo in
            guard let self = self else { return false }
            self.editor?.widgetMoved(self, at: mouseInfo.globalPosition)
            return true
        }

        addLayer(moveLayer, origin: point)
        updateMoveHandleLayer()
    }

    private func createMoveShadowLayer(at point: CGPoint) {
        let shadow = CALayer()
        shadow.frame = CGRect(origin: point, size: .zero)
        shadow.backgroundColor = .clear

        shadow.shadowOpacity = 1
        shadow.shadowOffset = CGSize(width: 0, height: 3)
        shadow.shadowRadius = 8.0
        shadow.shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.1)

        let shadowLayer = Layer(name: LayerName.moveShadow.rawValue, layer: shadow)
        addLayer(shadowLayer, origin: point, at: 0)
        updateMoveShadowLayer()
    }

    var opacityAnimation: CABasicAnimation {
        let anim = CABasicAnimation()
        anim.duration = 0.3
        return anim
    }

    @discardableResult
    private func createCheckboxLayer(at point: CGPoint) -> CheckboxLayer? {
        let checkboxLayer = CheckboxLayer(name: LayerName.checkbox.rawValue) { [weak self] checked in
            guard let textNode = self as? TextNode else { return }
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
        updateMoveHandleLayer()
        updateMoveShadowLayer()
    }

    private func updateBulletLayer() {
        guard let bulletLayer = self.layers[LayerName.bullet.rawValue] else { return }
        if bulletLayer.frame.origin.y != bulletLayerPositionY {
            bulletLayer.frame.origin = CGPoint(x: Self.bulletLayerPositionX, y: bulletLayerPositionY)
        }
        bulletLayer.layer.opacity = Float((showDisclosureButton || !PreferencesManager.alwaysShowBullets) ? 0 : 1)
        bulletLayer.layer.isHidden = !self.isFocused && self.elementText.isEmpty && element.kind.isText
        if let placeHolder = (self as? TextNode)?.placeholder, !placeHolder.isEmpty, !(editor?.hasFocus ?? false) {
            bulletLayer.layer.isHidden = false
        }

        bulletLayer.layer.backgroundColor = BeamColor.Editor.bullet.cgColor
    }

    private func updateMoveHandleLayer() {
        guard let moveLayer = self.layers[LayerName.moveHandle.rawValue] else { return }
        moveLayer.layer.opacity = frontmostHover ? 1 : 0
        moveLayer.layer.isHidden = self.elementText.isEmpty && element.kind.isText
        moveLayer.layer.backgroundColor = cursorHoverMoveHandle ? BeamColor.Editor.moveHandleHover.cgColor : BeamColor.Editor.bullet.cgColor
        moveLayer.layer.frame.origin = moveHandlePosition

        moveLayer.setAccessibilityLabel("moveHandle")
        moveLayer.setAccessibilityRole(NSAccessibility.Role.handle)
    }

    private func updateMoveShadowLayer() {
        guard let shadowLayer = self.layers[LayerName.moveShadow.rawValue] else { return }
        let shadowSize = CGSize(width: self.frame.size.width + childInset * CGFloat(depth) + 20, height: self.frame.size.height)
        let frame = CGRect(origin: shadowLayer.frame.origin, size: shadowSize)
        shadowLayer.layer.frame = frame
        shadowLayer.layer.cornerRadius = isDraggedForMove ? 6.0 : 0.0
        shadowLayer.layer.shadowRadius = isDraggedForMove ? 8.0 : 0.0
        shadowLayer.layer.backgroundColor = isDraggedForMove ? BeamColor.Generic.background.cgColor : .clear
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
        indentLayer.frame = NSRect(x: Self.indentLayerPositionX, y: y - 4, width: 0.5, height: frame.height - y)
        indentLayer.layer.isHidden = !(showDisclosureButton && self.open)
        indentLayer.layer.backgroundColor = BeamColor.Editor.indentBackground.cgColor
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
