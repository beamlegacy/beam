import AppKit
import BeamCore

final class CollapsedContentLayer: ButtonLayer {

    var isFocused: Bool = false {
        didSet {
            guard isFocused != oldValue else { return }
            state = isFocused ? .focused : .default
        }
    }

    /// The maximum width available to display this layer. The actual width may be smaller depending on the
    /// amount of text.
    var maxWidth: CGFloat = 500 {
        didSet {
            guard maxWidth != oldValue else { return }

            cachedTextInformation = nil
            updateLayout()
        }
    }

    var firstBaseline: CGFloat? { textInformation.firstBaseline }

    private let text: String

    private var textInformation: TextInformation {
        if cachedTextInformation == nil {
            cachedTextInformation = TextInformation(text: text, state: state, textWidth: textWidth)
        }
        return cachedTextInformation!
    }

    private var cachedTextInformation: TextInformation?

    private lazy var textLayer: CATextLayer = {
        let layer = SmoothTextLayer()

        let actions = [
            kCAOnOrderIn: NSNull(),
            kCAOnOrderOut: NSNull(),
            kCATransition: NSNull(),
            "sublayers": NSNull(),
            "contents": NSNull(),
            "bounds": NSNull()
        ]

        layer.actions = actions
        layer.isWrapped = true
        return layer
    }()

    private lazy var imageLayer: CALayer = {
        let layer = CALayer()
        layer.frame.size = imageSize
        return layer
    }()

    private lazy var arrowSymbolLayer: CALayer = {
        let layer = CALayer()
        layer.frame.size = arrowSize
        return layer
    }()

    private var state: State = .default {
        didSet {
            guard state != oldValue else { return }

            // Invalidate to take the new visual state into account
            cachedTextInformation = nil

            updateColors()
        }
    }

    private let imageSize = CGSize(width: 16, height: 16)
    private let arrowSize = CGSize(width: 10, height: 10)
    private let horizontalPaddingBetweenImageAndText: CGFloat = 6
    private let trailingPadding: CGFloat = 12

    private var textWidth: CGFloat {
        return maxWidth - imageLayer.frame.width - horizontalPaddingBetweenImageAndText - trailingPadding
    }

    private var defaultImage: NSImage? {
        NSImage(named: "field-web")?.fill(color: BeamColor.LightStoneGray.nsColor)
    }

    init(name: String, text: String, activated: @escaping () -> Void) {
        self.text = text

        super.init(name, CALayer(), activated: activated)

        prepareLayers()
        updateColors()

        hovered = { [weak self] isHovered in
            guard let strongSelf = self else { return }
            if strongSelf.isFocused {
                self?.state = .focused
            } else {
                self?.state = isHovered ? .hovered : .default
            }
        }

        layout = { [weak self] in
            self?.updateLayout()
        }
    }

    func setImage(_ image: NSImage?) {
        imageLayer.contents = image
    }

    /// Resizes the layer bounds so it just encloses its content.
    func sizeToFit() {
        let width = imageLayer.frame.width + horizontalPaddingBetweenImageAndText + textLayer.frame.width + trailingPadding
        layer.bounds.size = CGSize(width: width, height: textLayer.frame.height)
    }

    private func prepareLayers() {
        cursor = .pointingHand

        setImage(defaultImage)

        textLayer.addSublayer(arrowSymbolLayer)
        layer.addSublayer(textLayer)
        layer.addSublayer(imageLayer)
    }

    private func updateLayout() {
        updateText()

        layoutImage()
        layoutText()
        layoutArrowSymbol()
    }

    private func updateColors() {
        updateText()
        updateArrowSymbolColor()
    }

    private func updateText() {
        textLayer.string = textInformation.attributedString
    }

    private func updateArrowSymbolColor() {
        let arrowSymbolColor = state.beamColor
        let image = NSImage(named: "editor-url")?.fill(color: arrowSymbolColor.nsColor)
        arrowSymbolLayer.contents = image
    }

    private func layoutImage() {
        guard let firstBaseline = textInformation.firstBaseline else { return }

        let positionY = firstBaseline - imageLayer.frame.height + 3
        imageLayer.frame.origin = CGPoint(x: 0, y: positionY)
    }

    private func layoutText() {
        let textLayerOrigin = CGPoint(x: imageLayer.frame.maxX + horizontalPaddingBetweenImageAndText, y: 0)
        textLayer.frame = CGRect(origin: textLayerOrigin, size: textInformation.boundingRectSize)
    }

    private func layoutArrowSymbol() {
        guard let lastCaret = textInformation.lastCaret else { return }

        arrowSymbolLayer.frame.origin = CGPoint(
            x: lastCaret.offset.x + 1,
            y: lastCaret.offset.y - 1
        )
    }

    // MARK: -

    private struct TextInformation {

        let attributedString: NSAttributedString
        let boundingRectSize: CGSize

        var firstBaseline: CGFloat? {
            guard let firstLine = firstLine else { return nil }
            return CGFloat(firstLine.typographicBounds.ascent) + firstLine.frame.minY
        }

        var lastCaret: Caret? {
            let caretCount = textFrame.carets.count
            guard caretCount >= 2 else { return nil }
            return textFrame.carets[caretCount - 2]
        }

        private let textFrame: TextFrame

        private var firstLine: TextLine? { textFrame.lines.first }

        init(text: String, state: State, textWidth: CGFloat) {
            attributedString = Self.makeAttributedString(from: text, state: state)
            boundingRectSize = Self.makeBoundingRect(for: attributedString, textWidth: textWidth)
            textFrame = Self.makeTextFrame(for: attributedString, textWidth: textWidth)
        }

        private static func makeBoundingRect(for attributedString: NSAttributedString, textWidth: CGFloat) -> CGSize {
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            return CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: attributedString.length),
                nil,
                CGSize(width: textWidth, height: 0),
                nil
            )
        }

        private static func makeTextFrame(for attributedString: NSAttributedString, textWidth: CGFloat) -> TextFrame {
            TextFrame.create(
                string: attributedString,
                atPosition: .zero,
                textWidth: textWidth,
                singleLineHeightFactor: nil,
                maxHeight: nil
            )
        }

        private static func makeAttributedString(from text: String, state: State) -> NSAttributedString {
            var beamText = BeamText(attributedString: NSAttributedString(string: text))

            let linkAttributes: [BeamText.Attribute] = [.link("")]
            beamText.addAttributes(linkAttributes, to: 0..<text.count)

            let mouseInteraction = MouseInteraction(
                type: state.mouseInteractionType,
                range: NSRange(location: 0, length: beamText.count)
            )

            let config = BeamTextAttributedStringBuilder.Config(
                elementKind: .bullet,
                ranges: beamText.ranges,
                fontSize: PreferencesManager.editorFontSize,
                fontColor: BeamColor.Generic.text.staticColor,
                searchedRanges: [],
                mouseInteraction: mouseInteraction
            )

            let builder = BeamTextAttributedStringBuilder()

            let styleAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: state.beamColor.cgColor,
                .font: BeamFont.medium(size: 14).nsFont
            ]

            return builder.build(config: config).addAttributes(styleAttributes)
        }

    }

    // MARK: -

    private enum State {

        case `default`, hovered, focused

        var beamColor: BeamColor {
            switch self {
            case .focused: return BeamColor.Editor.linkActive
            default: return BeamColor.Editor.link
            }
        }

        var mouseInteractionType: MouseInteractionType {
            switch self {
            case .hovered: return .hovered
            default: return .unknown
            }
        }

    }

}
