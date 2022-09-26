//
//  CodeNode.swift
//  Beam
//
//  Created by Thomas on 07/09/2022.
//

import BeamCore
import Combine
import Lottie

final class CodeNode: TextNode, Collapsible {
    private var toggleButtonBeamLayer: CollapseButtonLayer?

    private var toggleButtonOrigin: CGPoint {
        CGPoint(
            x: availableWidth + childInset,
            y: contentsTop + 2
        )
    }

    var isCollapsed = false {
        didSet {
            guard isCollapsed != oldValue else { return }
            element.collapsed = isCollapsed

            if isCollapsed {
                collapse()
            } else {
                expand()
            }
            
            invalidateLayout()
        }
    }
    var isHoverCollapseExpandButton = false
    var lottieView: Lottie.AnimationView?

    var mediaName: String {
        return "media name"
    }

    var mediaURL: URL? {
        return nil
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat) {
        isCollapsed = element.collapsed

        super.init(parent: parent, element: element, availableWidth: availableWidth)

        addBackgroundLayer()

        if !element.isProxy {
            addToggleButton()
        }
    }

    override var pressEnterInsertsNewLine: Bool { true }
    override var moveDownInsertsNewElementIfNeeded: Bool { true }
    override var allowFormatting: Bool { false }

    override func subscribeToElement(_ element: BeamElement) {
        elementScope.removeAll()

        element.$text
            .sink { [unowned self] newValue in
                if isCollapsed {
                    let string = buildAttributedString(for: newValue)
                    let width = contentsWidth - textPadding.left - textPadding.right
                    let height = inInitialLayout ? maxVisibleHeight : nil
                    let position = CGPoint(x: textPadding.left, y: textPadding.top)
                    let textFrame = TextFrame.create(string: string,
                                                     atPosition: position,
                                                     textWidth: width,
                                                     singleLineHeightFactor: PreferencesManager.editorLineHeight,
                                                     maxHeight: height)
                    displayFirstLine(of: newValue, in: textFrame)
                } else {
                    displayText(newValue)
                }
            }.store(in: &elementScope)

        element.$kind
            .sink { [unowned self] newValue in
                elementKind = newValue
                self.invalidateText()
            }.store(in: &elementScope)

        open = element.open
    }

    override var textPadding: NSEdgeInsets {
        return NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
    }

    override func updateLayout() {
        super.updateLayout()
        layoutBackgroundLayer()
        layoutToggleButton()
    }

    override func updateRendering() -> CGFloat {
        return super.updateRendering() - 6
    }

    override var frontmostHover: Bool {
        didSet {
            toggleButtonBeamLayer?.layer.isHidden = !isCollapsed && !frontmostHover
        }
    }

    override func onFocus() {
        if isCollapsed {
            isCollapsed = false
            toggleButtonBeamLayer?.isCollapsed = false
        }
    }

    private func collapse() {
        if isFocused {
            root?.focusedWidget = nil
        }
        if let textFrame = textFrame {
            displayFirstLine(of: elementText, in: textFrame)
        }
    }

    private func expand() {
        displayText(element.text)
    }

    private func displayFirstLine(of text: BeamText, in textFrame: TextFrame) {
        guard let line = textFrame.lines.first else { return }
        guard !line.range.isEmpty else { return }
        var range = line.range
        if text[range.upperBound-1] == "\n" {
            range = range.lowerBound..<(range.upperBound-1)
        }
        let newText = text.extract(range: range)
        displayText(newText)
    }

    private func displayText(_ text: BeamText) {
        elementText = text
        self.updateActionLayerVisibility(hidden: elementText.isEmpty || !isFocused)
        self.invalidateText()
    }

    private func addBackgroundLayer() {
        let layer = CodeNodeBackgroundLayer()
        layer.backgroundColor = CodeNodeBackgroundLayer.backgroundColor
        layer.borderColor = CodeNodeBackgroundLayer.backgroundBorderColor
        layer.cornerRadius = 3.0
        layer.borderWidth = 1.0
        layer.zPosition = -2 // below text selection

        let background = Layer(name: "background", layer: layer)
        addLayer(background)
    }

    private func layoutBackgroundLayer() {
        guard let background = layers["background"] else { return }

        CATransaction.disableAnimations {
            background.frame.origin = .zero
            background.frame.size = layer.frame.size
            background.frame.origin.x += contentsLead
            background.frame.size.width -= contentsLead
        }
    }

    private func addToggleButton() {
        toggleButtonBeamLayer = CollapseButtonLayer(name: "toggle", isCollapsed: isCollapsed) { [weak self] isCollapsed in
            self?.isCollapsed = isCollapsed
        }

        toggleButtonBeamLayer?.layer.isHidden = !isCollapsed
        toggleButtonBeamLayer?.collapseText = NSLocalizedString("Collapse", comment: "Embed collapse button label")
        toggleButtonBeamLayer?.expandText = NSLocalizedString("Expand", comment: "Embed expand button label")

        addLayer(toggleButtonBeamLayer!)
    }

    private func layoutToggleButton() {
        CATransaction.disableAnimations {
            toggleButtonBeamLayer?.layer.frame.origin = toggleButtonOrigin
            toggleButtonBeamLayer?.isCompact = (editor?.useCompactTrailingGutter ?? false)
        }
    }

    // MARK: - CALayerDelegate

    override public func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        layers["background"]?.layer.setNeedsDisplay()
    }
}

private final class CodeNodeBackgroundLayer: CALayer {
    static var backgroundColor: CGColor {
        BeamColor.combining(lightColor: .Mercury, darkColor: .Mercury).cgColor
    }
    static var backgroundBorderColor: CGColor {
        BeamColor.combining(lightColor: .AlphaGray.alpha(0.4), darkColor: .AlphaGray).cgColor
    }

    override func display() {
        CATransaction.disableAnimations {
            NSAppearance.withAppAppearance {
                backgroundColor = Self.backgroundColor
                borderColor = Self.backgroundBorderColor
            }
        }
    }
}
