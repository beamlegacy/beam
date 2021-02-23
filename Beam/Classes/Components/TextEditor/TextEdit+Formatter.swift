//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static var xPosInlineFormatter: CGFloat = 55
    private static var centerTextXPosInlineFormatter: CGFloat = 80
    private static let yPosInlineFormatter: CGFloat = 50
    private static let yPosDismissInlineFormatter: CGFloat = 35
    private static let bottomConstraint: CGFloat = -25
    private static let inlineFormatterType: [FormatterType] = [.h1, .h2, .bullet, .checkmark, .bold, .italic, .link]
    private static let persistentFormatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]

    private static var isSelectableContent = true
    private static var bottomAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?

    private static var deboucingKeyEventTimer: Timer?

    // MARK: - UI
    internal func initPersistentFormatterView() {
        guard persistentFormatter == nil else { return }

        persistentFormatter = FormatterView(viewType: .persistent)
        persistentFormatter?.alphaValue = 0

        guard let formatterView = persistentFormatter,
              let contentView = window?.contentView else { return }

        formatterView.translatesAutoresizingMaskIntoConstraints = false
        formatterView.items = BeamTextEdit.persistentFormatterType

        addConstraint(to: formatterView, with: contentView)
        contentView.addSubview(formatterView)
        activeLayoutConstraint(for: formatterView)

        formatterView.didSelectFormatterType = { [unowned self] (type, isActive) -> Void in
            self.selectFormatterAction(type, isActive)
        }

        showOrHidePersistentFormatter(isPresent: true)
    }

    internal func initInlineFormatterView(isHyperlinkView: Bool = false) {
        guard inlineFormatter == nil else { return }

        inlineFormatter = FormatterView(viewType: .inline)

        guard let formatterView = inlineFormatter else { return }

        formatterView.items = BeamTextEdit.inlineFormatterType
        formatterView.didSelectFormatterType = {[unowned self] (type, isActive) -> Void in
            self.selectFormatterAction(type, isActive)
        }

        formatterView.didPressValideLink = {[unowned self] (hyperlink) -> Void in
            let (isValidUrl, url) = hyperlink.validUrl()

            guard let node = focussedWidget as? TextNode,
                isValidUrl else {
                self.showOrHideInlineFormatter(isPresent: false)
                return
            }

            self.showOrHideInlineFormatter(isPresent: false)
            node.text.addAttributes([.link(url)], to: node.selectedTextRange.isEmpty ? 0..<node.text.text.count : node.selectedTextRange )
        }

        formatterView.didPressDeleteLink = {[unowned self] (hyperlink) -> Void in
            guard let node = focussedWidget as? TextNode else { return }

            self.showOrHideInlineFormatter(isPresent: false)
            node.text.removeAttributes([.link("")], from: 0..<hyperlink.count)
        }

        formatterView.alphaValue = 0
        formatterView.frame = NSRect(x: 0, y: 0, width: formatterView.idealSize.width, height: formatterView.idealSize.height)

        if isHyperlinkView {
            formatterView.showHyperLinkView()
        }

        formatterView.layer?.zPosition = 1
        addSubview(formatterView)
    }

    // MARK: - Methods
    internal func showOrHidePersistentFormatter(isPresent: Bool) {
        guard let persistentFormatter = persistentFormatter else { return }

        persistentFormatter.wantsLayer = true
        persistentFormatter.layoutSubtreeIfNeeded()

        NSAnimationContext.runAnimationGroup ({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            persistentFormatter.alphaValue = isPresent ? 1 : 0
            persistentFormatter.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }

    internal func showOrHideInlineFormatter(isPresent: Bool, isDragged: Bool = false) {
        guard let inlineFormatter = inlineFormatter else { return }

        // Alpha animation
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.3
            inlineFormatter.animator().alphaValue = isPresent ? 1 : 0
            isInlineFormatterHidden = isPresent ? false : true

            if !isPresent && isDragged { dismissFormatterView(inlineFormatter) }

        NSAnimationContext.endGrouping()
        NSAnimationContext.current.completionHandler = { [weak self] in
            guard let self = self else { return }
            if !isPresent && !isDragged { self.dismissFormatterView(inlineFormatter) }
        }
    }

    internal func updateInlineFormatterView(_ isDragged: Bool = false, _ isKeyEvent: Bool = false) {
        detectFormatterType()

        if isKeyEvent && !rootNode.textIsSelected {
            // Enable timer to hide inline formatter during the key selection
            BeamTextEdit.deboucingKeyEventTimer = Timer.scheduledTimer(withTimeInterval: 0.23, repeats: false, block: { [weak self] (_) in
                guard let self = self else { return }
                self.showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
                self.showOrHidePersistentFormatter(isPresent: true)
            })

            return
        } else if rootNode.state.nodeSelection != nil {
            // Invalid the timer when we select all bullet
            BeamTextEdit.deboucingKeyEventTimer?.invalidate()
        } else if !rootNode.textIsSelected {
            // Invalid the timer & hide the inline formatter when nothing is selected
            BeamTextEdit.deboucingKeyEventTimer?.invalidate()
            showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
            showOrHidePersistentFormatter(isPresent: true)
        }

        updateInlineFormatterFrame()
    }

    internal func updateInlineFormaterOnHover(_ currentNode: TextNode?, _ position: NSPoint, _ frame: NSRect?, _ url: URL?) {
        initInlineFormatterView(isHyperlinkView: true)

        guard let view = inlineFormatter,
              let node = currentNode,
              let frame = frame,
              let url = url,
              isInlineFormatterHidden else { return }

        showOrHideInlineFormatter(isPresent: true)
        focussedWidget = node

        view.urlValue = url.absoluteString
        view.frame.origin.y = (frame.maxY + node.offsetInDocument.y) - 55
        view.frame.origin.x = convert(position, to: nil).x - 50
    }

    internal func detectFormatterType() {
        guard let node = focussedWidget as? TextNode else { return }

        let selectedTextRange = node.selectedTextRange
        let cursorPosition = rootNode.cursorPosition
        let beginPosition = selectedTextRange.lowerBound == 0 ? cursorPosition..<cursorPosition + 1 : cursorPosition - 1..<cursorPosition
        let endPosition = cursorPosition..<cursorPosition + 1
        var range = selectedTextRange.lowerBound == 0 && selectedTextRange.upperBound > 0 ? beginPosition : endPosition
        var types: [FormatterType] = []

        if rootNode.state.nodeSelection != nil { range = 0..<node.text.text.count }

        rootNode.state.attributes = []
        setActiveFormatters(types)

        switch node.elementKind {
        case .heading(1):
            types.append(.h1)
        case .heading(2):
            types.append(.h2)
        case .quote(1, node.text.text, node.text.text):
            types.append(.quote)
        default:
            break
        }

        node.text.extractFormatterType(from: range).forEach { type in
            types.append(type)

            switch type {
            case .bold:
                rootNode.state.attributes.append(.strong)
            case .italic:
                rootNode.state.attributes.append(.emphasis)
            case .strikethrough:
                rootNode.state.attributes.append(.strikethrough)
            default:
                break
            }
        }

        setActiveFormatters(types)
    }

    internal func updateFormatterView(with type: FormatterType, attribute: BeamText.Attribute? = nil, kind: ElementKind = .bullet) {
        guard let node = focussedWidget as? TextNode else { return }

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

        if let inlineFormatter = inlineFormatter {
            inlineFormatter.setActiveFormatter(type)
        }

        if let persistentFormatter = persistentFormatter {
            persistentFormatter.setActiveFormatter(type)
        }
    }

    internal func selectFormatterAction(_ type: FormatterType, _ isActive: Bool) {
        guard let node = focussedWidget as? TextNode else { return }

        switch type {
        case .h1:
            changeTextFormat(with: node, kind: .heading(1), isActive: isActive)
        case .h2:
            changeTextFormat(with: node, kind: .heading(2), isActive: isActive)
        case .quote:
            changeTextFormat(with: node, kind: .quote(1, node.text.text, node.text.text), isActive: isActive)
        case .code:
            print("code")
        case .bold:
            updateAttributeState(with: node, attribute: .strong, isActive: isActive)
        case .italic:
            updateAttributeState(with: node, attribute: .emphasis, isActive: isActive)
        case .strikethrough:
            updateAttributeState(with: node, attribute: .strikethrough, isActive: isActive)
        default:
            break
        }
    }

    internal func dismissFormatterView(_ view: FormatterView?) {
        guard view != nil else { return }
        view?.removeFromSuperview()

        if view == persistentFormatter {
            persistentFormatter = nil
        } else {
            BeamTextEdit.isSelectableContent = true
            isInlineFormatterHidden = true
            inlineFormatter = nil
        }
    }

    private func changeTextFormat(with node: TextNode, kind: ElementKind, isActive: Bool) {
        if rootNode.state.nodeSelection != nil {
            guard let nodeSelection = rootNode.state.nodeSelection else { return }

            nodeSelection.nodes.forEach({ node in
                node.element.kind = isActive ? .bullet : kind
            })
        } else {
            node.element.kind = isActive ? .bullet : kind
        }
    }

    private func updateAttributeState(with node: TextNode, attribute: BeamText.Attribute, isActive: Bool) {
        let attributes = rootNode.state.attributes

        if rootNode.state.nodeSelection != nil {
            guard let nodeSelection = rootNode.state.nodeSelection else { return }

            nodeSelection.nodes.forEach({ node in
                addAttribute(to: node, with: attribute, by: 0..<node.text.text.count, isActive)
            })
        } else if rootNode.textIsSelected {
            addAttribute(to: node, with: attribute, by: node.selectedTextRange, isActive)
        }

        guard let index = attributes.firstIndex(of: attribute),
              attributes.contains(attribute),
              isActive else {
                rootNode.state.attributes.append(attribute)
                return
        }

        rootNode.state.attributes.remove(at: index)
    }

    private func addAttribute(to node: TextNode, with attribute: BeamText.Attribute, by range: Range<Int>, _ isActive: Bool) {
        isActive ?
            node.text.removeAttributes([attribute], from: range) :
            node.text.addAttributes([attribute], to: range)
    }

    private func setActiveFormatters(_ types: [FormatterType]) {
        if let inlineFormatter = inlineFormatter {
            inlineFormatter.setActiveFormmatters(types)
        }

        if let persistentFormatter = persistentFormatter {
            persistentFormatter.setActiveFormmatters(types)
        }
    }

    private func updateInlineFormatterFrame() {
        guard let node = focussedWidget as? TextNode,
              let view = inlineFormatter else { return }

        let (xOffset, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)
        let yOffset = rect.maxY + node.offsetInDocument.y - 10
        let textFrame = isBig ? (textWidth / 2) - BeamTextEdit.centerTextXPosInlineFormatter : BeamTextEdit.centerTextXPosInlineFormatter
        let yPos = yOffset - BeamTextEdit.yPosInlineFormatter
        let xPos = xOffset + (centerText ? textFrame : BeamTextEdit.xPosInlineFormatter)
        let centerXPos = (frame.width - textWidth) / 2
        let currentLowerBound = currentTextRange.lowerBound
        let selectedLowerBound = node.selectedTextRange.lowerBound

        view.frame.origin.x = rootNode.state.nodeSelection != nil ? (centerText ? centerXPos : 200) : xPos

        if currentLowerBound == selectedLowerBound && BeamTextEdit.isSelectableContent {
            BeamTextEdit.isSelectableContent = false
            view.frame.origin.y = rootNode.state.nodeSelection != nil ? node.offsetInDocument.y - 40 : yPos
        }

        if currentLowerBound > selectedLowerBound || selectedLowerBound > currentLowerBound {
            BeamTextEdit.isSelectableContent = currentLowerBound > selectedLowerBound
            view.frame.origin.y = rootNode.state.nodeSelection != nil ? node.offsetInDocument.y - 40 : yPos
        }
    }

    private func addConstraint(to view: FormatterView, with contentView: NSView) {
        BeamTextEdit.bottomAnchor = view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: BeamTextEdit.bottomConstraint)
        BeamTextEdit.centerXAnchor = view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
    }

    private func activeLayoutConstraint(for view: FormatterView) {
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
}
