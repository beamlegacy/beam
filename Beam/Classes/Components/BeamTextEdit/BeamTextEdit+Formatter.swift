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
    private static let inlineFormatterType: [FormatterType] = [.h1, .h2, .bullet, .checkmark, .bold, .italic, .link]
    private static let persistentFormatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]

    private static var bottomAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?
    private static var debounceKeyEventTimer: Timer?
    private static var debounceMouseEventTimer: Timer?

    private static var formatterPresentDelay: TimeInterval = 0.7
    private static var formatterDismissDelay: TimeInterval = 0.2

    // MARK: - UI
    internal func initPersistentFormatterView() {
        guard persistentFormatter == nil else { return }

        persistentFormatter = TextFormatterView(viewType: .persistent)
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

        if isHyperlinkView {
            initHyperlinkFormatter()
        } else {
            let formatterView = TextFormatterView(viewType: .inline)
            formatterView.items = BeamTextEdit.inlineFormatterType
            formatterView.didSelectFormatterType = {[unowned self] (type, isActive) -> Void in
                self.selectFormatterAction(type, isActive)
            }
            inlineFormatter = formatterView
        }
        guard let formatterView = inlineFormatter else { return }
        let idealSize = formatterView.idealSize
        formatterView.frame = NSRect(x: 0, y: 0, width: idealSize.width, height: idealSize.height)
        addSubview(formatterView)
        formatterView.layer?.zPosition = 10
    }

    // MARK: - Methods
    internal func showOrHidePersistentFormatter(isPresent: Bool) {
        guard let persistentFormatter = persistentFormatter else { return }
        if isPresent {
            persistentFormatter.animateOnAppear()
        } else {
            persistentFormatter.animateOnDisappear()
        }
    }

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
        guard let inlineFormatter = inlineFormatter else { return }

        if isPresent {
            inlineFormatter.animateOnAppear {
                completionHandler?()
            }
        } else {
            inlineFormatter.animateOnDisappear { [weak self] in
                guard let self = self else { return }
                if !isPresent && !isDragged { self.dismissFormatterView(inlineFormatter) }
                completionHandler?()
            }
            if isDragged { self.dismissFormatterView(inlineFormatter) }
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

        moveInlineFormatterAboveSelection()
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func detectFormatterType() {
        guard let node = focusedWidget as? TextNode else { return }

        var types: [FormatterType] = []

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

        if let inlineFormatter = inlineFormatter as? TextFormatterView {
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
        case .link:
            dismissFormatterView(inlineFormatter)
            showLinkFormatterForSelection()
            moveInlineFormatterAboveSelection()
        default:
            break
        }
    }

    internal func dismissFormatterView(_ view: FormatterView?) {
        guard view != nil else { return }
        view?.removeFromSuperview()

        if view == persistentFormatter {
            persistentFormatter = nil
        } else if view == inlineFormatter {
            ContextMenuPresenter.shared.dismissMenu()
            isInlineFormatterHidden = true
            inlineFormatter = nil
            cursorStartPosition = 0
            formatterTargetRange = nil
            formatterTargetNode = nil
            clearDebounceTimer()
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
        if let inlineFormatter = inlineFormatter as? TextFormatterView {
            inlineFormatter.setActiveFormmatters(types)
        }

        if let persistentFormatter = persistentFormatter {
            persistentFormatter.setActiveFormmatters(types)
        }
    }

    // MARK: Private Methods (UI)
    private func moveInlineFormatterAboveSelection() {
        guard let node = focusedWidget as? TextNode,
              let view = inlineFormatter,
              let line = node.lineAt(index: node.cursorPosition),
              let currentLine = node.lineAt(index: cursorStartPosition) else { return }

        let leftMargin: CGFloat = centerText ? 145 : 200 // Value to move the inline formatter to the left
        let middleFrame = (frame.width - textWidth) / 2
        let idealSize = view.idealSize
        let (xOffset, rect) = node.offsetAndFrameAt(index: node.cursorPosition)
        let yPos = rect.maxY + node.offsetInDocument.y - idealSize.height - BeamTextEdit.yPosInlineFormatter
        let xPos = xOffset + (centerText ? middleFrame - leftMargin : BeamTextEdit.xPosInlineFormatter) + childInsetFrom(node)

        view.frame.origin.x = rootNode.state.nodeSelection != nil ? (centerText ? middleFrame : leftMargin) : xPos

        // Update Y position only if the current selected line is equal to selected line
        if !(node.selectedTextRange.upperBound > node.selectedTextRange.lowerBound && currentLine < line) {
            view.frame.origin.y = rootNode.state.nodeSelection != nil ? node.offsetInDocument.y - idealSize.height - 8 : yPos
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

    func clearDebounceTimer() {
        if let debounce = BeamTextEdit.debounceMouseEventTimer {
            debounce.invalidate()
            BeamTextEdit.debounceMouseEventTimer = nil
        }
    }
}
