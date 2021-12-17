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
        return NSSize(width: contentsWidth, height: 0.5)
    }

    private var lineLayer: CALayer?
    private var focusLayer: CALayer?
    private var lastApperance: NSAppearance?

    override func setBottomPaddings(withDefault: CGFloat) {
        super.setBottomPaddings(withDefault: 17)
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        super.init(parent: parent, element: element, availableWidth: availableWidth)
        setupDivider()
    }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat?) {
        super.init(editor: editor, element: element, availableWidth: availableWidth)
        setupDivider()
    }

    func setupDivider() {
        let focus = CALayer()
        focus.cornerRadius = 2
        layer.addSublayer(focus)
        focusLayer = focus

        let line = CALayer()
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
        if NSApp.effectiveAppearance != lastApperance {
            lastApperance = NSApp.effectiveAppearance
            NSAppearance.withAppAppearance {
                lineLayer?.compositingFilter = NSApp.effectiveAppearance.isDarkMode ? "screenBlendMode" : "multiplyBlendMode"
                focusLayer?.backgroundColor = BeamColor.Generic.textSelection.cgColor
                lineLayer?.backgroundColor = BeamColor.Mercury.cgColor
            }
        }

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
