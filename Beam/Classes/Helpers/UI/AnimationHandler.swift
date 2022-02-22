import AppKit

/// An object triggering actions when an animation stops.
final class AnimationHandler: NSObject {

    private weak var layer: CALayer?
    private let removeAllAnimationsWhenFinished: Bool

    /// A block executed when the animation has ended.
    private let animationDidStopHandler: ((Bool) -> Void)?

    /// A block executed when the animation has completed by reaching the end of its duration.
    private let animationDidFinishHandler: (() -> Void)?

    init(
        layer: CALayer? = nil,
        removeAllAnimationsWhenFinished: Bool = false,
        animationDidStopHandler: ((Bool) -> Void)? = nil,
        animationDidFinishHandler: (() -> Void)? = nil
    ) {
        self.layer = layer
        self.removeAllAnimationsWhenFinished = removeAllAnimationsWhenFinished
        self.animationDidStopHandler = animationDidStopHandler
        self.animationDidFinishHandler = animationDidFinishHandler

        super.init()
    }

}

// MARK: - CAAnimationDelegate

extension AnimationHandler: CAAnimationDelegate {

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            animationDidFinishHandler?()
        }

        if flag, removeAllAnimationsWhenFinished {
            layer?.removeAllAnimations()
        }

        animationDidStopHandler?(flag)
    }

}
