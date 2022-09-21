import AppKit
import Lottie

final class CollapseButtonLayer: ButtonLayer {

    var collapseText: String = "Collapse" {
        didSet {
            updateLabel()
        }
    }

    var expandText: String = "Expand" {
        didSet {
            updateLabel()
        }
    }

    var isCollapsed: Bool {
        didSet {
            guard isCollapsed != oldValue else { return }

            updateLabel()
            updateSymbolLayer()
            updateColors()
            invalidateLayout()
        }
    }

    var isCompact: Bool = false {
        didSet {
            textLayer.opacity = isCompact ? 0 : 1
        }
    }

    private lazy var textLayer: CATextLayer = {
        let layer = CATextLayer()
        layer.fontSize = 12
        layer.font = BeamFont.medium(size: 12).nsFont
        return layer
    }()

    private var symbolLayer: CALayer!
    private var symbolAnimationView: AnimationView!

    private var state: State = .default {
        didSet {
            guard state != oldValue else { return }
            updateColors()
        }
    }

    init(name: String, isCollapsed: Bool, activated: @escaping (Bool) -> Void) {
        self.isCollapsed = isCollapsed

        super.init(name, CALayer())

        prepareLayers()
        updateLabel()
        updateSymbolLayer()
        updateLayout()

        let parentMouseDown = mouseDown
        let parentMouseUp = mouseUp

        mouseDown = { [weak self] mouseInfo in
            let result = parentMouseDown(mouseInfo)

            self?.state = .highlighted
            self?.playAnimation()

            return result
        }

        mouseUp = { [weak self] mouseInfo in
            self?.state = (self?.hovering ?? false) ? .hovered : .default

            self?.isCollapsed.toggle()
            // Update `isCollapsed` state before it gets sent to `activated()`
            return parentMouseUp(mouseInfo)
        }

        hovered = { [weak self] isHovered in
            self?.state = isHovered ? .hovered : .default
            self?.playAnimation()
        }

        let customActivated = activated

        self.activated = { [weak self] _ in
            guard let isCollapsed = self?.isCollapsed else { return }
            customActivated(isCollapsed)
        }

        layout = { [weak self] in
            self?.updateLayout()
        }
    }

    override func updateColors() {
        super.updateColors()

        let beamColor = state.beamColor
        textLayer.foregroundColor = beamColor.cgColor
        symbolAnimationView.setColor(beamColor)
    }

    private func prepareLayers() {
        layer.addSublayer(textLayer)
    }

    private func updateSymbolLayer() {
        symbolLayer?.removeFromSuperlayer()

        symbolAnimationView = makeSymbolAnimationView()
        symbolLayer = symbolAnimationView.animationLayer

        layer.addSublayer(symbolLayer)
    }

    private func updateLayout() {
        // Enlarge the width if needed, but never shrink it, so that the cursor stays within the hit target even if the label width becomes shorter
        let width = max(textLayer.frame.width, textLayer.preferredFrameSize().width)

        symbolLayer.frame.origin = .zero

        textLayer.frame = CGRect(
            x: symbolLayer.frame.maxX + 4,
            y: -1,
            width: isCompact ? 0 : width,
            height: textLayer.preferredFrameSize().height
        )

        layer.frame.size = preferredFrameSize()
    }

    private func updateLabel() {
        let string = isCollapsed ? expandText : collapseText
        textLayer.string = string
    }

    private func playAnimation() {
        symbolAnimationView.play()
    }

    private func makeSymbolAnimationView() -> AnimationView {
        let animationName = isCollapsed ? "editor-embed_expand" : "editor-embed_collapse"
        return AnimationView(name: animationName)
    }

    private func preferredFrameSize() -> CGSize {
        CGSize(
            width: symbolLayer.frame.width + 4 + textLayer.frame.width,
            height: max(symbolLayer.frame.height, textLayer.frame.height)
        )
    }

    // MARK: -

    private enum State {

        case `default`, hovered, highlighted

        var beamColor: BeamColor {
            switch self {
            case .default: return BeamColor.Editor.collapseExpandButton
            case .hovered: return BeamColor.Editor.collapseExpandButtonHover
            case .highlighted: return BeamColor.Editor.collapseExpandButtonClicked
            }
        }

    }

}
