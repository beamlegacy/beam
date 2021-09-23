//
//  DividerNode.swift
//  Beam
//
//  Created by Remi Santos on 22/09/2021.
//

import Foundation
import BeamCore

public class DividerNode: ElementNode {

    override var shouldDisplayBullet: Bool {
        false
    }

    public override var textCount: Int {
        0 // skippable node
    }

    override var selectionLayerHeight: CGFloat {
        selectedAlone ? 18 : super.selectionLayerHeight
    }
    override var selectionLayerPosY: CGFloat {
        selectedAlone ? 8 : super.selectionLayerPosY
    }

    private var visibleSize: CGSize {
        return NSSize(width: contentsWidth, height: 2)
    }

    private var lineLayer: CALayer?
    private var focusLayer: CALayer?

    init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element)
        setupDivider()
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element)
        setupDivider()
    }

    func setupDivider() {
        let focus = CALayer()
        focus.backgroundColor = BeamColor.Generic.textSelection.cgColor
        layer.addSublayer(focus)
        focusLayer = focus

        let line = CALayer()
        line.compositingFilter = "multiplyBlendMode"
        line.backgroundColor = BeamColor.Mercury.cgColor
        layer.addSublayer(line)
        lineLayer = line
        var updatedPadding = contentsPadding
        updatedPadding.top = 17
        updatedPadding.bottom = 17

        contentsPadding = updatedPadding

        setAccessibilityLabel("DividerNode")
        setAccessibilityRole(.splitter)
    }

    override func updateRendering() -> CGFloat {
        visibleSize.height
    }

    override func updateLayout() {
        super.updateLayout()
        let padding = contentsPadding
        var size = visibleSize
        size.width = selectionLayerWidth
        let origin = CGPoint(x: -padding.left + Self.indentLayerPosX, y: padding.top - (size.height / 2))
        lineLayer?.frame = CGRect(origin: origin, size: size)
        focusLayer?.frame = CGRect(x: origin.x, y: selectionLayerPosY, width: size.width, height: selectionLayerHeight)
    }

    public override func updateElementCursor() {
         // never shows cursor
    }

    override func updateSelectionLayer() {
        super.updateSelectionLayer()
        focusLayer?.isHidden = !isFocused || selected
    }

    override func updateFocus() {
        super.updateFocus()
        focusLayer?.isHidden = !isFocused || selected
    }

    override func onUnfocus() {
        updateFocus()
    }

    override func onFocus() {
        updateFocus()
    }

}
