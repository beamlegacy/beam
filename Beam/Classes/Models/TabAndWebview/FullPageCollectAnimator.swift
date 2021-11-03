//
//  FullPageCollectAnimator.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 03/11/2021.
//

import Foundation

struct FullPageCollectAnimator {

    let webView: BeamWebView

    // swiftlint:disable function_body_length
    // swiftlint:disable large_tuple
    func buildFullPageCollectAnimation() -> (hoverLayer: CALayer, hoverGroup: CAAnimationGroup, webViewGroup: CAAnimationGroup)? {

        guard let layer = webView.layer else { return nil }

        let scaleDown = CABasicAnimation(keyPath: "transform.scale")
        scaleDown.fromValue = 1.0
        scaleDown.toValue = 0.97
        scaleDown.duration = 0.15
        scaleDown.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let cornerRadiusDown = CABasicAnimation(keyPath: "cornerRadius")
        cornerRadiusDown.fromValue = 0
        cornerRadiusDown.toValue = 10
        cornerRadiusDown.duration = 0.15
        cornerRadiusDown.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let scaleUp = CASpringAnimation(keyPath: "transform.scale")
        scaleUp.fromValue = 0.97
        scaleUp.toValue = 1.0
        scaleUp.stiffness = 400
        scaleUp.damping = 24
        scaleUp.duration = 0.2
        scaleUp.beginTime = 0.15

        let cornerRadiusUp = CABasicAnimation(keyPath: "cornerRadius")
        cornerRadiusUp.fromValue = 10
        cornerRadiusUp.toValue = 0
        cornerRadiusUp.duration = 0.2
        cornerRadiusUp.beginTime = 0.15
        cornerRadiusUp.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let hoverLayer = CALayer()
        hoverLayer.frame = webView.frame
        hoverLayer.backgroundColor = BeamColor.Beam.cgColor
        hoverLayer.opacity = 0.0
        hoverLayer.name = "FullPageCollectHover"

        let hoverColorUp = CABasicAnimation(keyPath: "opacity")
        hoverColorUp.fromValue = 0.0
        hoverColorUp.toValue = 0.20
        hoverColorUp.duration = 0.10
        hoverColorUp.beginTime = 0.05
        hoverColorUp.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let hoverColorDown = CABasicAnimation(keyPath: "opacity")
        hoverColorDown.fromValue = 0.20
        hoverColorDown.toValue = 0.0
        hoverColorDown.duration = 0.20
        hoverColorDown.beginTime = 0.15
        hoverColorDown.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        //We need to center the anchor point for the animation to animate around the center
        //We also need to update the position of the layer as changing the anchorPoint make it move
        if layer.anchorPoint == .zero {
            let newAnchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.anchorPoint = newAnchorPoint

            var position = layer.position
            position.x += webView.bounds.maxX * newAnchorPoint.x
            position.y += webView.bounds.maxY * newAnchorPoint.y
            layer.position = position
        }

        let webViewGroup = CAAnimationGroup()
        webViewGroup.animations = [scaleDown, cornerRadiusDown, scaleUp, cornerRadiusUp]

        let hoverGroup = CAAnimationGroup()
        hoverGroup.animations = [hoverColorUp, hoverColorDown]

        return (hoverLayer, hoverGroup, webViewGroup)
    }
}
