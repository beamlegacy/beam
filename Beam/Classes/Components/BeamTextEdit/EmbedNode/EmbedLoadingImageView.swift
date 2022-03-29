import AppKit

final class EmbedLoadingImageView: NSView {

    private var imageLayer: CALayer!
    private let imageColor = BeamColor.AlphaGray

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        prepare()
        startAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        if let scaleFactor = window?.backingScaleFactor {
            DispatchQueue.main.async { [weak imageLayer] in
                imageLayer?.contentsScale = scaleFactor
            }
        }
    }

    func setImage(_ image: NSImage) {
        image.size = bounds.size

        DispatchQueue.main.async { [weak self, weak imageLayer] in
            guard let strongSelf = self else { return }

            CATransaction.disableAnimations {
                imageLayer?.frame = strongSelf.bounds
            }

            imageLayer?.contents = image.fill(color: strongSelf.imageColor.nsColor)
        }
    }

    private func prepare() {
        imageLayer = CALayer()

        layer = CALayer()
        layer?.addSublayer(imageLayer)
    }

    private func startAnimation() {
        let animation = Self.makeAnimation()
        imageLayer.add(animation, forKey: Self.animationKey)
    }

    // MARK: - Animation

    private static let animationKey = "pulseAnimation"

    private static func makeAnimation() -> CAAnimation {
        let animation = CAKeyframeAnimation()
        animation.keyPath = "transform"
        animation.isRemovedOnCompletion = false
        animation.repeatCount = .infinity
        animation.duration = 1.6

        let scaleUpTimingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
        let scaleDownTimingFunction = CAMediaTimingFunction(controlPoints: 0.01, 0.3, 0.58, 1)
        animation.timingFunctions = [scaleUpTimingFunction, scaleDownTimingFunction]

        animation.keyTimes = [
            0,
            NSNumber(value: 0.6 / 1.6),
            1
        ]

        animation.values = [
            CATransform3DIdentity,
            CATransform3DMakeScale(1.1, 1.1, 1.1),
            CATransform3DIdentity
        ]

        return animation
    }

}
