import AppKit

final class EmbedAnimator {

    /// A multiplier applied to all animation timings, to slow down animations for debugging purposes.
    private static let animationDurationFactor: CGFloat = 1

    // MARK: - Expand animations

    static func makeExpandedContentPresentationAnimation() -> CAAnimation {
        let fadeInAnimation = CAKeyframeAnimation()
        fadeInAnimation.keyPath = "opacity"
        fadeInAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fadeInAnimation.duration = 0.18 * animationDurationFactor
        fadeInAnimation.keyTimes = [0, NSNumber(value: 0.05 / 0.18), 1]
        fadeInAnimation.values = [0, 0, 1]
        fadeInAnimation.fillMode = .forwards

        let zoomInAnimation = CABasicAnimation()
        zoomInAnimation.keyPath = "transform"
        zoomInAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        zoomInAnimation.duration = 0.20 * animationDurationFactor
        zoomInAnimation.fromValue = CATransform3DMakeScale(0.1, 0.1, 0.1)
        zoomInAnimation.toValue = CATransform3DIdentity
        zoomInAnimation.fillMode = .forwards

        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [fadeInAnimation, zoomInAnimation]
        groupAnimation.duration = 0.26 * animationDurationFactor
        groupAnimation.fillMode = .forwards
        groupAnimation.isRemovedOnCompletion = false
        return groupAnimation
    }

    static func makeCollapsedContentDismissalAnimation() -> CAAnimation {
        let fadeOutAnimation = CAKeyframeAnimation()
        fadeOutAnimation.keyPath = "opacity"
        fadeOutAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fadeOutAnimation.duration = 0.26 * animationDurationFactor
        fadeOutAnimation.keyTimes = [0, NSNumber(value: 0.16 / 0.26), 1]
        fadeOutAnimation.values = [1, 1, 0]
        fadeOutAnimation.fillMode = .forwards
        fadeOutAnimation.isRemovedOnCompletion = false
        return fadeOutAnimation
    }

    // MARK: - Collapse animations

    static func makeExpandedContentDismissalAnimation() -> CAAnimation {
        let fadeOutAnimation = CAKeyframeAnimation()
        fadeOutAnimation.keyPath = "opacity"
        fadeOutAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fadeOutAnimation.duration = 0.15 * animationDurationFactor
        fadeOutAnimation.keyTimes = [0, NSNumber(value: 0.05 / 0.15), 1]
        fadeOutAnimation.values = [1, 1, 0]
        fadeOutAnimation.fillMode = .forwards

        let zoomOutAnimation = CABasicAnimation()
        zoomOutAnimation.keyPath = "transform"
        zoomOutAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        zoomOutAnimation.duration = 0.2 * animationDurationFactor
        zoomOutAnimation.fromValue = CATransform3DIdentity
        zoomOutAnimation.toValue = CATransform3DMakeScale(0.1, 0.1, 0.1)
        zoomOutAnimation.fillMode = .forwards

        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [fadeOutAnimation, zoomOutAnimation]
        groupAnimation.duration = 0.2 * animationDurationFactor
        groupAnimation.fillMode = .forwards
        groupAnimation.isRemovedOnCompletion = false
        return groupAnimation
    }

    static func makeCollapsedContentPresentationAnimation() -> CAAnimation {
        let fadeInAnimation = CABasicAnimation()
        fadeInAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fadeInAnimation.duration = 0.1 * animationDurationFactor
        fadeInAnimation.keyPath = "opacity"
        fadeInAnimation.fromValue = 0
        fadeInAnimation.toValue = 1
        fadeInAnimation.fillMode = .forwards
        fadeInAnimation.isRemovedOnCompletion = false
        return fadeInAnimation
    }

}
