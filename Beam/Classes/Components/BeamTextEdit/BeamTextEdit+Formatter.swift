//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//
// swiftlint:disable file_length

import Cocoa
import BeamCore

extension BeamTextEdit {

    // MARK: - Properties
    private static let xPosInlineFormatter: CGFloat = 32
    private static let yPosInlineFormatter: CGFloat = 28
    private static let bottomConstraint: CGFloat = -55
    private static let inlineFormatterType: [TextFormatterType] = [.bold, .italic, .strikethrough, .underline, .internalLink, .link]

    private static var bottomAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?
    private static var debounceKeyEventTimer: Timer?
    private static var debounceMouseEventTimer: Timer?

    private static var formatterPresentDelay: TimeInterval = 0.7
    private static var formatterDismissDelay: TimeInterval = 0.2

    static var formatterPlaceholderAttribute: BeamText.Attribute {
        let placeholderDecoration: [NSAttributedString.Key: Any] = [
            .foregroundColor: BeamColor.LightStoneGray.nsColor,
            .boxBackgroundColor: BeamColor.Mercury.nsColor
        ]
        return BeamText.Attribute.decorated(AttributeDecoratedValueAttributedString(attributes: placeholderDecoration))
    }

    // MARK: - UI

    internal func initInlineFormatterView(isHyperlinkView: Bool = false) {
        guard inlineFormatter == nil else { return }

        if isHyperlinkView {
            initHyperlinkFormatter()
        } else {
            let formatterView = TextFormatterView(viewType: .inline)
            formatterView.items = BeamTextEdit.inlineFormatterType
            formatterView.delegate = self
            inlineFormatter = formatterView
        }
        guard let formatterView = inlineFormatter else { return }
        setupInlineFormatterView(formatterView)
    }

    internal func setupInlineFormatterView(_ formatterView: FormatterView) {
        let idealSize = formatterView.idealSize
        formatterView.frame = NSRect(x: 0, y: 0, width: idealSize.width, height: idealSize.height)
        addSubview(formatterView)
        formatterView.layer?.zPosition = 10
    }

    // MARK: - Methods

    func debounceShowHideInlineFormatter(_ show: Bool, completionHandler: (() -> Void)? = nil) {
        let delay = show ? Self.formatterPresentDelay : Self.formatterDismissDelay
        BeamTextEdit.debounceMouseEventTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { [weak self] (_) in
            guard let self = self else { return }

            if show || self.inlineFormatter?.isMouseInsideView == false {
                self.showOrHideInlineFormatter(isPresent: show)
                completionHandler?()
            }
            self.clearDebounceTimer()
        })
    }

    internal func showOrHideInlineFormatter(isPresent: Bool, isDragged: Bool = false, completionHandler: (() -> Void)? = nil) {
        guard let formatterView = inlineFormatter else {
            completionHandler?()
            return
        }

        if isPresent {
            formatterView.animateOnAppear {
                completionHandler?()
            }
        } else {
            formatterView.animateOnDisappear {
                formatterView.removeFromSuperview()
                completionHandler?()
            }
            dismissFormatterView(formatterView, removeView: isDragged)
        }
    }

    internal func updateInlineFormatterView(isDragged: Bool = false, isKeyEvent: Bool = false) {
        guard inlineFormatter != nil else { return }
        detectTextFormatterType()

        let formatterHandlesKeyEvents = inlineFormatter?.handlesTyping == true
        let hasNodeSelection = rootNode.state.nodeSelection != nil
        let hasTextSelected = rootNode.textIsSelected
        if isKeyEvent && !hasTextSelected && !hasNodeSelection && !formatterHandlesKeyEvents {
            // Enable timer to hide inline formatter during key selection
            BeamTextEdit.debounceKeyEventTimer = Timer.scheduledTimer(withTimeInterval: 0.23, repeats: false, block: { [weak self] (_) in
                guard let self = self else { return }
                self.showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
            })
            return
        } else if isKeyEvent && formatterHandlesKeyEvents,
                  let node = formatterTargetNode,
                  let targetRange = formatterTargetRange {
            if targetRange.lowerBound <= node.cursorPosition {
                var text = node.text.text
                let fullRange = targetRange.lowerBound..<node.cursorPosition
                text = text.substring(range: targetRange.lowerBound..<node.cursorPosition)
                if inlineFormatter?.formatterHandlesInputText(text) == true {
                    if let typingAttributes = inlineFormatter?.typingAttributes {
                        node.text.setAttributes(typingAttributes, to: fullRange)
                    }
                } else {
                    showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
                }
            } else {
                showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
            }
        } else if hasNodeSelection {
            // Invalid the timer when we select all bullet
            BeamTextEdit.debounceKeyEventTimer?.invalidate()
        } else if !hasTextSelected && (!isKeyEvent || !formatterHandlesKeyEvents) {
            // Invalid the timer & hide the inline formatter when nothing is selected
            BeamTextEdit.debounceKeyEventTimer?.invalidate()
            showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
        }

        if inlineFormatter is TextFormatterView {
            moveInlineFormatterAtSelection()
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func detectTextFormatterType() {
        guard let node = focusedWidget as? TextNode else { return }

        var types: [TextFormatterType] = []
        switch node.element.kind {
        case .heading(1):
            types.append(.h1)
        case .heading(2):
            types.append(.h2)
        case .quote(1, node.text.text, node.text.text):
            types.append(.quote)
        default:
            break
        }

        for attributes in rootNode.state.attributes {
            switch attributes {
            case .strong:
                types.append(.bold)
            case .emphasis:
                types.append(.italic)
            case .strikethrough:
                types.append(.strikethrough)
            case .underline:
                types.append(.underline)
            default:
                break
            }
        }

        setActiveFormatters(types)
    }

    internal func updateFormatterView(with type: TextFormatterType, attribute: BeamText.Attribute? = nil, kind: ElementKind = .bullet) {
        guard let node = focusedWidget as? TextNode else { return }

        var hasAttribute = false

        if let attribute = attribute {
            hasAttribute = rootNode.state.attributes.contains(attribute)
        }

        if type == .h1 && node.element.kind.rawValue == kind.rawValue ||
           type == .h2 && node.element.kind.rawValue == kind.rawValue ||
           type == .quote && node.element.kind.rawValue == kind.rawValue ||
           type == .code && node.element.kind.rawValue == kind.rawValue {
            hasAttribute = node.element.kind == kind
        }

        selectFormatterAction(type, hasAttribute)
        detectTextFormatterType()
    }

    private func elementAndAttribute(for formatterType: TextFormatterType,
                                     in node: TextNode) -> (ElementKind?, BeamText.Attribute?) {
        var attribute: BeamText.Attribute?
        var elementKind: ElementKind?
        switch formatterType {
        case .bold:
            attribute = .strong
        case .italic:
            attribute = .emphasis
        case .strikethrough:
            attribute = .strikethrough
        case .underline:
            attribute = .underline
        case .h1:
            elementKind = .heading(1)
        case .h2:
            elementKind = .heading(2)
        case .quote:
            elementKind = .quote(1, node.text.text, node.text.text)
        case .checkmark:
            elementKind = .check(false)
        default:
            break
        }
        return (elementKind, attribute)
    }

    internal func selectFormatterAction(_ type: TextFormatterType, _ isActive: Bool) {
        guard let node = focusedWidget as? TextNode else { return }
        var (newElementKind, newAttribute) = elementAndAttribute(for: type, in: node)
        var dismissFormatter = false
        var cancelSelection = false
        switch type {
        case .link:
            showLinkFormatterForSelection()
            moveInlineFormatterAtSelection()
        case .internalLink:
            dismissFormatter = true
            if let linkAttr = handleInternalLinkFormat(in: node) {
                cancelSelection = true
                newAttribute = linkAttr
            }
        default:
            break
        }

        if dismissFormatter {
            dismissFormatterView(inlineFormatter)
        }
        if let newAttribute = newAttribute {
            updateAttributeState(with: node, attribute: newAttribute, isActive: isActive)
        }
        if let newElementKind = newElementKind {
            changeTextFormat(with: node, kind: newElementKind, isActive: isActive)
        }
        if cancelSelection {
            node.root?.cancelNodeSelection()
            node.root?.cancelSelection()
        }
    }

    internal func dismissFormatterView(_ view: FormatterView?, removeView: Bool = true) {
        guard view != nil else { return }
        if removeView {
            view?.removeFromSuperview()
        }
        clearFormatterTypingAttributes(view)
        if view == inlineFormatter {
            CustomPopoverPresenter.shared.dismissMenu()
            isInlineFormatterHidden = true
            inlineFormatter = nil
            formatterTargetRange = nil
            formatterTargetNode = nil
            clearDebounceTimer()
        }
    }

    private func clearFormatterTypingAttributes(_ view: FormatterView?) {
        guard let targetNode = formatterTargetNode, let attributes = view?.typingAttributes else { return }
        targetNode.text.removeAttributes(attributes, from: targetNode.text.wholeRange)
    }

    internal func moveInlineFormatterAtSelection(below: Bool = false) {
        guard let node = focusedWidget as? TextNode,
              let view = inlineFormatter else { return }
        view.frame.origin = containedFormatterPosition(in: node, formatter: view, tryBelow: below)
    }

    private func containedFormatterPosition(in node: TextNode, formatter: FormatterView, tryBelow: Bool) -> CGPoint {
        let idealSize = formatter.idealSize
        var yPos = node.offsetInDocument.y - idealSize.height - 8
        var xPos: CGFloat = node.offsetInDocument.x
        if rootNode.state.nodeSelection == nil {
            let (xOffset, rect) = node.offsetAndFrameAt(index: node.cursorPosition)
            let positionBelow = rect.maxY + node.offsetInDocument.y + 8
            if tryBelow && positionBelow + idealSize.height < self.frame.height {
                // below
                yPos = positionBelow
            } else {
                // above
                yPos = rect.minY + node.offsetInDocument.y - idealSize.height - 8
            }
            xPos += xOffset - (idealSize.width / 2)
            if yPos < 0 {
                if xPos > idealSize.width / 2 {
                    // on the left
                    xPos -= idealSize.width / 2 + 8
                } else {
                    // or on the right
                    xPos += idealSize.width
                }
                yPos = max(0, rect.minY + node.offsetInDocument.y - idealSize.height / 2)
            }
        }
        xPos = xPos.clamp(0, self.frame.width - idealSize.width)
        yPos = yPos.clamp(0, self.frame.height - idealSize.height)
        return CGPoint(x: xPos, y: yPos)
    }

    private func handleInternalLinkFormat(in node: TextNode) -> BeamText.Attribute? {
        makeInternalLinkForSelectionOrShowFormatter(for: node, applyFormat: false)
    }

    // MARK: Private Methods (Text Formatting)
    private func changeTextFormat(with node: TextNode, kind: ElementKind, isActive: Bool) {
        if rootNode.state.nodeSelection != nil {
            rootNode.note?.cmdManager.beginGroup(with: "ChangeTextFormat")
            guard let nodeSelection = rootNode.state.nodeSelection else { return }

            nodeSelection.nodes.forEach({ node in
                if let node = node as? TextNode {
                    rootNode.note?.cmdManager.formatText(in: node, for: kind, with: nil, for: nil, isActive: isActive)
                }
            })
            rootNode.note?.cmdManager.endGroup()
        } else {
            rootNode.note?.cmdManager.formatText(in: node, for: kind, with: nil, for: nil, isActive: isActive)
        }
    }

    private func updateAttributeState(with node: TextNode, attribute: BeamText.Attribute, isActive: Bool) {

        if rootNode.state.nodeSelection != nil {
            guard let nodeSelection = rootNode.state.nodeSelection else { return }
            rootNode.note?.cmdManager.beginGroup(with: "UpdateAttributes")

            nodeSelection.nodes.forEach({ node in
                if let node = node as? TextNode {
                    rootNode.note?.cmdManager.formatText(in: node, for: nil, with: attribute, for: 0..<node.element.text.text.count, isActive: isActive)
                }
            })
            rootNode.note?.cmdManager.endGroup()
        } else if rootNode.textIsSelected {
            rootNode.note?.cmdManager.formatText(in: node, for: nil, with: attribute, for: node.selectedTextRange, isActive: isActive)
        } else {
            if let index = rootNode?.state.attributes.firstIndex(of: attribute),
               ((rootNode?.state.attributes.contains(attribute)) != nil), isActive {
                rootNode?.state.attributes.remove(at: index)
            } else {
                rootNode?.state.attributes.append(attribute)
            }
        }
    }

    private func setActiveFormatters(_ types: [TextFormatterType]) {
        if let inlineFormatter = inlineFormatter as? TextFormatterView {
            inlineFormatter.setActiveFormatters(types)
        }
    }

    // MARK: Private Methods (UI)
    private func addConstraint(to view: FormatterView, with contentView: NSView) {
        BeamTextEdit.bottomAnchor = view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: BeamTextEdit.bottomConstraint)
        BeamTextEdit.centerXAnchor = view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
    }

    private func activateLayoutConstraint(for view: FormatterView) {
        let widthAnchor = view.widthAnchor.constraint(equalToConstant: view.idealSize.width)
        let heightAnchor = view.heightAnchor.constraint(equalToConstant: view.idealSize.height)

        guard let bottomAnchor = BeamTextEdit.bottomAnchor,
              let centerXAnchor = BeamTextEdit.centerXAnchor else { return }

        NSLayoutConstraint.activate([
            bottomAnchor,
            widthAnchor,
            heightAnchor,
            centerXAnchor
        ])
    }

    private func childInsetFrom(_ node: TextNode) -> CGFloat {
        var childInset = node.childInset

        // Inset calculation from the parent of the current node
        node.allParents.forEach { parent in
            childInset += parent.childInset
        }

        return childInset
    }

    func clearDebounceTimer() {
        if let debounce = BeamTextEdit.debounceMouseEventTimer {
            debounce.invalidate()
            BeamTextEdit.debounceMouseEventTimer = nil
        }
    }
}

extension BeamTextEdit: TextFormatterViewDelegate {
    func textFormatterView(_ textFormatterView: TextFormatterView,
                           didSelectFormatterType type: TextFormatterType,
                           isActive: Bool) {
        self.selectFormatterAction(type, isActive)
    }
}
