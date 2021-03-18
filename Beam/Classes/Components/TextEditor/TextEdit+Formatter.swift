//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//
// swiftlint:disable file_length

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let xPosInlineFormatter: CGFloat = 32
    private static let yPosInlineFormatter: CGFloat = 60
    private static let bottomConstraint: CGFloat = -25
    private static let inlineFormatterType: [FormatterType] = [.h1, .h2, .bullet, .checkmark, .bold, .italic, .link]
    private static let persistentFormatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]

    private static var isSelectableContent = true
    private static var isExitingLink = false
    private static var bottomAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?
    private static var debounceKeyEventTimer: Timer?
    private static var debounceMouseEventTimer: Timer?

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
        activateLayoutConstraint(for: formatterView)

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

        formatterView.didPressValidLink = {[unowned self] link, oldLink -> Void in
            let (isValidUrl, validUrl) = link.validUrl()

            guard let node = focusedWidget as? TextNode, isValidUrl,
                  let noteTitle = node.elementNoteTitle else {
                    self.showOrHideInlineFormatter(isPresent: false)
                    return
            }

            if node.selectedTextRange.isEmpty || !oldLink.isEmpty {
                updateNodeWithLink(node: node, isDeleteMode: false, link: validUrl, oldLink)
            } else {
                let changeFormat = FormattingText(in: node.elementId, of: noteTitle, for: nil, with: .link(validUrl), for: node.selectedTextRange, isActive: false)
                rootNode.note?.cmdManager.run(command: changeFormat, on: rootNode.cmdContext)
            }

            self.showOrHideInlineFormatter(isPresent: false)
        }

        formatterView.didPressDeleteLink = {[unowned self] (hyperlink) -> Void in
            guard let node = focusedWidget as? TextNode else { return }

            updateNodeWithLink(node: node, isDeleteMode: true, link: hyperlink)
            self.showOrHideInlineFormatter(isPresent: false)
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
            // Enable timer to hide inline formatter during key selection
            BeamTextEdit.debounceKeyEventTimer = Timer.scheduledTimer(withTimeInterval: 0.23, repeats: false, block: { [weak self] (_) in
                guard let self = self else { return }
                self.showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
                self.showOrHidePersistentFormatter(isPresent: true)
            })

            return
        } else if rootNode.state.nodeSelection != nil {
            // Invalid the timer when we select all bullet
            BeamTextEdit.debounceKeyEventTimer?.invalidate()
        } else if !rootNode.textIsSelected {
            // Invalid the timer & hide the inline formatter when nothing is selected
            BeamTextEdit.debounceKeyEventTimer?.invalidate()
            showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
            showOrHidePersistentFormatter(isPresent: true)
        }

        updateInlineFormatterFrame()
    }

    internal func updateInlineFormaterOnHover(_ currentNode: TextNode?, _ position: NSPoint, _ frame: NSRect?, _ url: URL?) {
        initInlineFormatterView(isHyperlinkView: true)

        if let debounce = BeamTextEdit.debounceMouseEventTimer {
            debounce.invalidate()
            if !debounce.isValid { BeamTextEdit.isExitingLink = true }
        }

        guard let view = inlineFormatter,
              let hyperlinkView = view.hyperlinkView,
              let node = currentNode,
              let frame = frame,
              let url = url,
              isInlineFormatterHidden else { return }

        showOrHideInlineFormatter(isPresent: true)

        let trackingArea = NSTrackingArea(
            rect: hyperlinkView.bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self, userInfo: nil
        )

        hyperlinkView.addTrackingArea(trackingArea)

        view.urlValue = url.absoluteString
        view.frame.origin.y = (frame.maxY + node.offsetInDocument.y) - 55
        view.frame.origin.x = 60 + frame.maxX / 2
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func detectFormatterType() {
        guard let node = focusedWidget as? TextNode else { return }

        let selectedTextRange = node.selectedTextRange
        let cursorPosition = rootNode.cursorPosition
        let beginPosition = selectedTextRange.lowerBound == 0 ? cursorPosition..<cursorPosition + 1 : cursorPosition - 1..<cursorPosition
        let endPosition = cursorPosition..<cursorPosition + 1
        var selectedRange = selectedTextRange.lowerBound == 0 && selectedTextRange.upperBound > 0 ? beginPosition : endPosition
        var types: [FormatterType] = []

        // Get correct attribute range to update inline formatter state
        node.text.ranges.forEach { (range) in
            if !range.attributes.isEmpty && selectedTextRange == range.position..<range.end {
                selectedRange = selectedTextRange
            }
        }

        if rootNode.state.nodeSelection != nil { selectedRange = 0..<node.text.text.count }

        setActiveFormatters(types)

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
            default:
                break
            }
        }

        setActiveFormatters(types)
    }

    internal func updateFormatterView(with type: FormatterType, attribute: BeamText.Attribute? = nil, kind: ElementKind = .bullet) {
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

        if let inlineFormatter = inlineFormatter {
            inlineFormatter.setActiveFormatter(type)
        }

        if let persistentFormatter = persistentFormatter {
            persistentFormatter.setActiveFormatter(type)
        }
    }

    internal func selectFormatterAction(_ type: FormatterType, _ isActive: Bool) {
        guard let node = focusedWidget as? TextNode else { return }

        switch type {
        case .h1:
            changeTextFormat(with: node, kind: .heading(1), isActive: isActive)
        case .h2:
            changeTextFormat(with: node, kind: .heading(2), isActive: isActive)
        case .quote:
            changeTextFormat(with: node, kind: .quote(1, node.text.text, node.text.text), isActive: isActive)
        case .code:
            Logger.shared.logDebug("code")
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
            isInlineFormatterHidden = true
            inlineFormatter = nil
            cursorStartPosition = 0
            BeamTextEdit.isSelectableContent = true
            BeamTextEdit.debounceMouseEventTimer = nil
        }
    }

    internal func dismissHyperlinkView() {
        guard let view = inlineFormatter,
              view.hyperlinkView != nil else { return }

        if !view.urlValue.isEmpty && BeamTextEdit.debounceMouseEventTimer?.isValid == nil {
            initDebounceMouseEvent()
        }

        if !view.urlValue.isEmpty && BeamTextEdit.isExitingLink {
            BeamTextEdit.isExitingLink = false
            initDebounceMouseEvent()
        }
    }

    // MARK: Mouse Events
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard inlineFormatter?.hyperlinkView != nil else { return }
        BeamTextEdit.debounceMouseEventTimer?.invalidate()
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard let hyperlinkView = inlineFormatter?.hyperlinkView else { return }

        // Init debounce only when the textefield is not empty
        if !hyperlinkView.hyperlinkTextField.stringValue.isEmpty {
            initDebounceMouseEvent()
        }
    }

    // MARK: Private Methods (Text Formatting)
    private func changeTextFormat(with node: TextNode, kind: ElementKind, isActive: Bool) {
        if rootNode.state.nodeSelection != nil {
            rootNode.note?.cmdManager.beginGroup(with: "ChangeTextFormat")
            guard let nodeSelection = rootNode.state.nodeSelection else { return }

            nodeSelection.nodes.forEach({ node in
                if let noteTitle = node.elementNoteTitle {
                    let changeFormat = FormattingText(in: node.elementId, of: noteTitle, for: kind, with: nil, for: nil, isActive: isActive)
                    rootNode.note?.cmdManager.run(command: changeFormat, on: rootNode.cmdContext)
                }

            })
            rootNode.note?.cmdManager.endGroup()
        } else {
            guard let noteTitle = node.elementNoteTitle else { return }
            let changeFormat = FormattingText(in: node.elementId, of: noteTitle, for: kind, with: nil, for: nil, isActive: isActive)
            rootNode.note?.cmdManager.run(command: changeFormat, on: rootNode.cmdContext)
        }
    }

    private func updateAttributeState(with node: TextNode, attribute: BeamText.Attribute, isActive: Bool) {

        if rootNode.state.nodeSelection != nil {
            guard let nodeSelection = rootNode.state.nodeSelection else { return }
            rootNode.note?.cmdManager.beginGroup(with: "UpdateAttributes")

            nodeSelection.nodes.forEach({ node in
                if let noteTitle = node.elementNoteTitle {
                    let changeAttributes = FormattingText(in: node.elementId, of: noteTitle, for: nil, with: attribute, for: 0..<node.element.text.text.count, isActive: isActive)
                    rootNode.note?.cmdManager.run(command: changeAttributes, on: rootNode.cmdContext)
                }

            })
            rootNode.note?.cmdManager.endGroup()
        } else if rootNode.textIsSelected {
            guard let noteTitle = node.elementNoteTitle else { return }

            let changeAttributes = FormattingText(in: node.elementId, of: noteTitle, for: nil, with: attribute, for: node.selectedTextRange, isActive: isActive)
            rootNode.note?.cmdManager.run(command: changeAttributes, on: rootNode.cmdContext)
        } else {
            if let index = rootNode?.state.attributes.firstIndex(of: attribute),
               ((rootNode?.state.attributes.contains(attribute)) != nil), isActive {
                rootNode?.state.attributes.remove(at: index)
            } else {
                rootNode?.state.attributes.append(attribute)
            }
        }
    }

    private func setActiveFormatters(_ types: [FormatterType]) {
        if let inlineFormatter = inlineFormatter {
            inlineFormatter.setActiveFormmatters(types)
        }

        if let persistentFormatter = persistentFormatter {
            persistentFormatter.setActiveFormmatters(types)
        }
    }

    private func updateNodeWithLink(node: TextNode, isDeleteMode: Bool, link: String, _ oldLink: String? = nil) {
        node.text.ranges.forEach { range in
            range.attributes.forEach { attribute in
                switch attribute {
                case .link(let url):
                    if isDeleteMode && url == link {
                        node.text.removeAttributes([.link("")], from: range.position..<range.end)
                    } else if url == oldLink {
                        node.text.setAttributes([.link(link)], to: range.position..<range.end)
                    }
                default:
                    break
                }
            }
        }
    }

    // MARK: Private Methods (UI)
    private func updateInlineFormatterFrame() {
        guard let node = focusedWidget as? TextNode,
              let view = inlineFormatter,
              let line = node.lineAt(index: node.cursorPosition),
              let currentLine = node.lineAt(index: cursorStartPosition) else { return }

        let leftMargin: CGFloat = centerText ? 145 : 200 // Value to move the inline formatter to the left
        let middleFrame = (frame.width - textWidth) / 2
        let (xOffset, rect) = node.offsetAndFrameAt(index: node.cursorPosition)
        let yPos = rect.maxY + node.offsetInDocument.y - BeamTextEdit.yPosInlineFormatter
        let xPos = xOffset + (centerText ? middleFrame - leftMargin : BeamTextEdit.xPosInlineFormatter) + childInsetFrom(node)

        view.frame.origin.x = rootNode.state.nodeSelection != nil ? (centerText ? middleFrame : leftMargin) : xPos

        // Update Y position only if the current selected line is equal to selected line
        if !(node.selectedTextRange.upperBound > node.selectedTextRange.lowerBound && currentLine < line) {
            view.frame.origin.y = rootNode.state.nodeSelection != nil ? node.offsetInDocument.y - 40 : yPos
        }
    }

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

    private func initDebounceMouseEvent() {
        BeamTextEdit.debounceMouseEventTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { [weak self] (_) in
            guard let self = self else { return }

            self.showOrHideInlineFormatter(isPresent: false)
            BeamTextEdit.debounceMouseEventTimer = nil
            BeamTextEdit.isExitingLink = false
        })
    }
}
