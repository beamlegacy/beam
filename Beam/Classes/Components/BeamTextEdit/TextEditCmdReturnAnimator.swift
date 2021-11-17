//
//  TextEditCmdReturnAnimator.swift
//  Beam
//
//  Created by Remi Santos on 02/07/2021.
//

import Foundation

struct TextEditCmdReturnAnimator {

    var node: TextNode
    var editorLayer: CALayer?

    private let easeInOut = CAMediaTimingFunction(name: .easeInEaseOut)

    /// - Returns: true if animation is possible, node has enough information
    func startAnimation(completion: (() -> Void)?) -> Bool {
        guard let textLayer = node.textLayer?.layer else { return false }

        // INITIAL LAYOUT VALUES
        let parentLayer = textLayer.superlayer
        var cursorPosition = node.cursorPosition
        let (startLine, endLine) = linesToAnimate(node: node, cursorPosition: &cursorPosition)
        var layersToRemoveAfterAnimation = [CALayer]()
        var lastExpandedBoxRect = CGRect.zero
        var lastBoxLayer: CALayer?
        for i in startLine...endLine {
            let startOfText = node.beginningOfLineFromPosition(cursorPosition)
            let endOfText = node.endOfLineFromPosition(cursorPosition)
            let startRect = node.rectAt(sourcePosition: startOfText)
            let endRect = node.rectAt(sourcePosition: endOfText)
            var rect = startRect.union(endRect)
            rect.size.width *= 1.03 // faketext font is slighlty larger
            rect.origin.x += node.contentsLead

            guard endOfText <= node.attributedString.length else { return false }

            // LAYERS SETUP
            let (boxLayer, expandedBoxRect) = self.setupBoxLayer(for: rect, expandForIcon: i == endLine)
            parentLayer?.addSublayer(boxLayer)

            let text = node.attributedString.attributedSubstring(from: NSRange(location: startOfText, length: endOfText-startOfText))
            let (maskTextLayer, fakeTextLayer) = setupTextFakingLayers(originalTextLayer: textLayer, rect: rect, text: text)

            layersToRemoveAfterAnimation.append(maskTextLayer)
            layersToRemoveAfterAnimation.append(fakeTextLayer)
            lastExpandedBoxRect = expandedBoxRect
            lastBoxLayer = boxLayer
            cursorPosition = node.position(after: endOfText)
        }

        if let lastBoxLayer = lastBoxLayer {
            let iconLayer = setupIconLayer(expandedBoxRect: lastExpandedBoxRect)
            parentLayer?.insertSublayer(iconLayer, above: lastBoxLayer)
            layersToRemoveAfterAnimation.append(iconLayer)
        }

        // ANIMATIONS ENDS
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(300))) {
            completion?()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(1000))) {
                layersToRemoveAfterAnimation.forEach { $0.removeFromSuperlayer() }
            }
        }
        return true
    }

    private func linesToAnimate(node: TextNode, cursorPosition: inout Int) -> (startLine: Int, endLine: Int) {
        var startLine = node.lineAt(index: cursorPosition) ?? 0
        let endOfCurrentLine = node.endOfLineFromPosition(cursorPosition)
        let startOfCurrentLine = node.beginningOfLineFromPosition(cursorPosition)
        var endLine = startLine
        if let uneditableRange = node.uneditableRangeAt(index: cursorPosition) ?? node.uneditableRangeAt(index: endOfCurrentLine) ?? node.uneditableRangeAt(index: startOfCurrentLine) {
            startLine = node.lineAt(index: uneditableRange.lowerBound) ?? startLine
            endLine = node.lineAt(index: uneditableRange.upperBound) ?? endLine
            cursorPosition = uneditableRange.lowerBound
        }
        return (startLine, endLine)
    }

    private func setupBoxLayer(for rect: CGRect, expandForIcon: Bool)
    -> (boxLayer: CALayer, expandedBoxRect: CGRect) {
        let boxLayer = CAShapeLayer()
        var originalBoxRect = rect
        originalBoxRect.size.height = max(27, originalBoxRect.height)
        originalBoxRect.size.width += 4
        originalBoxRect = originalBoxRect.offsetBy(dx: -4, dy: -4)
        boxLayer.path = NSBezierPath(roundedRect: originalBoxRect, xRadius: 4, yRadius: 4).cgPath
        boxLayer.fillColor = BeamColor.Mercury.cgColor
        var expandedRect = originalBoxRect
        if expandForIcon {
            expandedRect.size.width += 25
        }

        // ANIMATIONS
        boxLayer.add(boxLayerAnimation(originalBoxRect: originalBoxRect, expandedRect: expandedRect), forKey: "boxAnimationGroup")

        return (boxLayer, expandedRect)
    }

    private func setupIconLayer(expandedBoxRect: NSRect) -> CALayer {
        let iconLayer = Layer.icon(named: "shortcut-cmd+return", color: BeamColor.LightStoneGray.nsColor)
        iconLayer.frame.origin = CGPoint(x: expandedBoxRect.maxX - 26, y: expandedBoxRect.minY + 7)

        // ANIMATIONS
        iconLayer.add(iconLayerAnimation(), forKey: "iconAnimationGroup")
        iconLayer.opacity = 0

        return iconLayer
    }

    private func setupTextFakingLayers(originalTextLayer: CALayer, rect: NSRect, text: NSAttributedString) -> (mask: CALayer, fakeText: CALayer) {
        let fakeTextLayer = CmdReturnFakeTextLayer()
        let textMaskLayer = CALayer()

        fakeTextLayer.contentsScale = originalTextLayer.contentsScale
        fakeTextLayer.frame = rect
        fakeTextLayer.isWrapped = true
        fakeTextLayer.setAttributedString(text)
        originalTextLayer.superlayer?.insertSublayer(fakeTextLayer, at: UINT32_MAX)

        textMaskLayer.frame = fakeTextLayer.frame.insetBy(dx: -6, dy: -6)
        textMaskLayer.backgroundColor = BeamColor.Generic.background.cgColor
        originalTextLayer.superlayer?.insertSublayer(textMaskLayer, above: originalTextLayer)

        // ANIMATIONS
        textMaskLayer.add(textFadeAnimation(), forKey: "textMaskOpacity")
        fakeTextLayer.add(textLayerAnimation(), forKey: "textLayerAnimationGroup")
        fakeTextLayer.add(textFadeAnimation(), forKey: "fakeTextOpacity")

        return (mask: textMaskLayer, fakeText: fakeTextLayer)
    }

    // MARK: - Animations makers
    private func textLayerAnimation() -> CAAnimation {
        let textLayerAnimationGroup = CAAnimationGroup()
        textLayerAnimationGroup.beginTime = CACurrentMediaTime() + 0.2
        textLayerAnimationGroup.duration = 1

        let translateDown = CASpringAnimation(keyPath: "transform.translation.y")
        translateDown.stiffness = 480
        translateDown.damping = 18
        translateDown.toValue = 7

        let translateUp = CASpringAnimation(keyPath: "transform.translation.y")
        translateUp.stiffness = 480
        translateUp.damping = 18
        translateUp.fromValue = 7
        translateUp.toValue = -7
        translateUp.beginTime = 0.125

        let translateLast = CASpringAnimation(keyPath: "transform.translation.y")
        translateLast.stiffness = 480
        translateLast.damping = 18
        translateLast.fromValue = 7
        translateLast.toValue = 0
        translateLast.beginTime = 0.225

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.keyTimes = [0, 0.125, 0.225, 0.325]
        fade.values = [1, 1, 0, 1]
        fade.timingFunctions = [easeInOut, easeInOut, easeInOut, easeInOut]

        textLayerAnimationGroup.animations = [translateDown, translateUp, translateLast, fade]
        return textLayerAnimationGroup
    }

    func textFadeAnimation() -> CAAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.1
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return fade
    }

    func iconLayerAnimation() -> CAAnimation {
        let iconAnimationGroup = CAAnimationGroup()
        iconAnimationGroup.beginTime = CACurrentMediaTime()
        iconAnimationGroup.duration = 1

        let translateIn = CASpringAnimation(keyPath: "transform.translation.x")
        translateIn.stiffness = 480
        translateIn.damping = 18
        translateIn.fromValue = 10
        translateIn.toValue = 0

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.keyTimes = [0, 0.1, 0.325, 0.425]
        fade.values = [0, 1, 1, 0]
        fade.timingFunctions = [easeInOut, easeInOut, easeInOut, easeInOut]

        let translateDown = CASpringAnimation(keyPath: "transform.translation.y")
        translateDown.stiffness = 480
        translateDown.damping = 18
        translateDown.toValue = 7
        translateDown.beginTime = 0.2

        let translateUp = CASpringAnimation(keyPath: "transform.translation.y")
        translateUp.stiffness = 480
        translateUp.damping = 18
        translateUp.fromValue = 7
        translateUp.toValue = -7
        translateUp.beginTime = 0.325

        iconAnimationGroup.animations = [translateIn, translateDown, translateUp, fade]
        return iconAnimationGroup
    }

    func boxLayerAnimation(originalBoxRect: CGRect, expandedRect: CGRect) -> CAAnimation {
        let boxAnimationGroup = CAAnimationGroup()
        boxAnimationGroup.beginTime = CACurrentMediaTime()
        boxAnimationGroup.duration = 1

        let boxFade = CABasicAnimation(keyPath: "fillColor")
        boxFade.fromValue = CGColor.clear
        boxFade.toValue = BeamColor.Mercury.cgColor
        boxFade.duration = 0.2
        boxFade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let boxWidth = CAKeyframeAnimation(keyPath: "path")
        boxWidth.keyTimes = [0, 0.1, 0.325, 0.450]
        let originalPath = NSBezierPath(roundedRect: originalBoxRect, xRadius: 4, yRadius: 4).cgPath
        let expandedPath = NSBezierPath(roundedRect: expandedRect, xRadius: 4, yRadius: 4).cgPath
        boxWidth.values = [
            originalPath,
            expandedPath,
            expandedPath,
            originalPath
        ]
        boxWidth.timingFunctions = [easeInOut, easeInOut, easeInOut, easeInOut]

        let translateDown = CASpringAnimation(keyPath: "transform.translation.y")
        translateDown.damping = 18
        translateDown.stiffness = 480
        translateDown.toValue = 7
        translateDown.beginTime = 0.2

        let translateUp = CASpringAnimation(keyPath: "transform.translation.y")
        translateUp.damping = 18
        translateUp.stiffness = 480
        translateUp.toValue = 0
        translateUp.beginTime = 0.325

        boxAnimationGroup.animations = [boxFade, boxWidth, translateDown, translateUp]
        return boxAnimationGroup
    }
}

private class CmdReturnFakeTextLayer: CATextLayer {
    func setAttributedString(_ attStr: NSAttributedString) {
        let copy = NSMutableAttributedString(attributedString: attStr)
        var fontSize: CGFloat = 15
        if let font = copy.attribute(.font, at: 0, effectiveRange: nil) as? NSFont {
            fontSize = font.pointSize
        }
        copy.removeAttribute(.font, range: copy.wholeRange)
        copy.addAttributes([.font: BeamFont.medium(size: fontSize).nsFont], range: copy.wholeRange)
        string = copy
    }
}
