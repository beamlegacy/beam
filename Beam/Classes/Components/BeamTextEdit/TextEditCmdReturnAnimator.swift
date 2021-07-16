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

    func startAnimation(completion: (() -> Void)?) {

        guard let textLayer = node.textLayer?.layer else { return }
        let parentLayer = textLayer.superlayer
        let cursorPosition = node.cursorPosition
        let startOfLine = node.beginningOfLineFromPosition(cursorPosition)
        let endOfLine = node.endOfLineFromPosition(cursorPosition)
        let startRect = node.rectAt(sourcePosition: startOfLine)
        let endRect = node.rectAt(sourcePosition: endOfLine)
        var rect = startRect.union(endRect)

        // LAYERS SETUP
        let boxLayer = CAShapeLayer()
        rect.origin.x += node.offsetAt(index: startOfLine)
        var originalBoxRect = rect
        originalBoxRect.size.height = max(27, originalBoxRect.height)
        originalBoxRect.size.width += 4
        originalBoxRect = originalBoxRect.offsetBy(dx: -4, dy: -4)
        var expandedRect = originalBoxRect
        expandedRect.size.width += 25
        boxLayer.path = NSBezierPath(roundedRect: originalBoxRect, xRadius: 4, yRadius: 4).cgPath
        boxLayer.fillColor = BeamColor.Mercury.cgColor
        parentLayer?.addSublayer(boxLayer)

        let text = node.attributedString.attributedSubstring(from: NSRange(location: startOfLine, length: endOfLine-startOfLine))
        let (maskTextLayer, fakeTextLayer) = setupTextFakingLayers(originalTextLayer: textLayer, rect: rect, text: text)

        let iconLayer = Layer.icon(named: "editor-cmdreturn", color: BeamColor.LightStoneGray.nsColor)
        iconLayer.frame.origin = CGPoint(x: expandedRect.maxX - 25, y: expandedRect.minY + 5)
        parentLayer?.insertSublayer(iconLayer, above: boxLayer)

        // ANIMATIONS
        // Text layer animation
        maskTextLayer.add(textFadeAnimation(), forKey: "textMaskOpacity")
        fakeTextLayer.add(textLayerAnimation(), forKey: "textLayerAnimationGroup")
        fakeTextLayer.add(textFadeAnimation(), forKey: "fakeTextOpacity")

        // icon animation
        iconLayer.add(iconLayerAnimation(), forKey: "iconAnimationGroup")
        iconLayer.opacity = 0

        // box animation
        boxLayer.add(boxLayerAnimation(originalBoxRect: originalBoxRect, expandedRect: expandedRect), forKey: "boxAnimationGroup")

        // Animation ends
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(300))) {
            completion?()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(1000))) {
                boxLayer.removeFromSuperlayer()
                iconLayer.removeFromSuperlayer()
                fakeTextLayer.removeFromSuperlayer()
                maskTextLayer.removeFromSuperlayer()
            }
        }
    }

    private func setupTextFakingLayers(originalTextLayer: CALayer, rect: NSRect, text: NSAttributedString) -> (mask: CALayer, fakeText: CALayer) {
        let fakeTextLayer = CmdReturnFakeTextLayer()
        let textMaskLayer = CALayer()

        fakeTextLayer.contentsScale = originalTextLayer.contentsScale
        fakeTextLayer.frame = rect
        fakeTextLayer.setAttributedString(text)
        originalTextLayer.superlayer?.addSublayer(fakeTextLayer)

        textMaskLayer.frame = fakeTextLayer.frame.insetBy(dx: -6, dy: -6)
        textMaskLayer.backgroundColor = BeamColor.Generic.background.cgColor
        originalTextLayer.superlayer?.insertSublayer(textMaskLayer, above: originalTextLayer)

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
