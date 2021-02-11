//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let xPosInlineFormatter: CGFloat = 55
    private static let startTopConstraint: CGFloat = 10
    private static let topConstraint: CGFloat = 12
    private static let startBottomConstraint: CGFloat = 35
    private static let bottomConstraint: CGFloat = -25
    private static let inlineFormatterType: [FormatterType] = [.h1, .h2, .bullet, .checkmark, .bold, .italic, .link]
    private static let persistentFormatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]

    private static var isSelectableContent = true
    private static var bottomAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?

    // MARK: - UI
    internal func initPersistentFormatterView() {
        guard persistentFormatter == nil else {
            showOrHidePersistentFormatter(isPresent: true)
            return
        }

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
            selectFormatterAction(type, isActive)
        }

        showOrHidePersistentFormatter(isPresent: true)
    }

    internal func initInlineFormatterView() {
        inlineFormatter = FormatterView(viewType: .inline)

        guard let formatterView = inlineFormatter,
              let contentView = window?.contentView else { return }

        formatterView.items = BeamTextEdit.inlineFormatterType
        formatterView.alphaValue = 0
        formatterView.frame = NSRect(x: 0, y: 0, width: formatterView.idealSize.width, height: formatterView.idealSize.height)
        contentView.addSubview(formatterView)
    }

    // MARK: - Methods
    internal func showOrHidePersistentFormatter(isPresent: Bool) {
        guard let persistentFormatter = persistentFormatter,
              let bottomAnchor = BeamTextEdit.bottomAnchor else { return }

        let showTimingFunction = CAMediaTimingFunction(controlPoints: 0.98, 0, 0.64, 0.4)
        let hideTimingFunction = CAMediaTimingFunction(controlPoints: 0.64, 0.4, 0, 0.98)

        persistentFormatter.wantsLayer = true
        persistentFormatter.layoutSubtreeIfNeeded()

        bottomAnchor.constant = isPresent ? BeamTextEdit.bottomConstraint : BeamTextEdit.startBottomConstraint

        NSAnimationContext.runAnimationGroup ({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = isPresent ? 0.4 : 0.5
            ctx.timingFunction = isPresent ? showTimingFunction : hideTimingFunction

            persistentFormatter.alphaValue = isPresent ? 1 : 0
            persistentFormatter.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }

    internal func showOrHideInlineFormatter(isPresent: Bool, isDragged: Bool = false) {
        guard let node = focussedWidget as? TextNode,
              let inlineFormatter = inlineFormatter else { return }

        let showTimingFunction = CAMediaTimingFunction(controlPoints: 0.64, 0.4, 0, 0.98)
        let hideTimingFunction = CAMediaTimingFunction(controlPoints: 0.98, 0, 0.64, 0.4)

        NSAnimationContext.runAnimationGroup ({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = isPresent ? 0.4 : 0.3
            ctx.timingFunction = isPresent ? showTimingFunction : hideTimingFunction

            inlineFormatter.alphaValue = isPresent ? 1 : 0
            inlineFormatter.layoutSubtreeIfNeeded()
            isInlineFormatterHidden = false

            updateInlineFormatterFrame(inlineFormatter, with: node, isPresent: isPresent)
            if !isPresent && isDragged { dismissFormatterView(inlineFormatter) }
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            if !isPresent && !isDragged { self.dismissFormatterView(inlineFormatter) }
        })
    }

    internal func updateInlineFormatterView(_ isDragged: Bool) {
        guard let node = focussedWidget as? TextNode,
              let inlineFormatter = inlineFormatter else { return }

        detectFormatterType()

        if !rootNode.textIsSelected {
            showOrHideInlineFormatter(isPresent: false, isDragged: isDragged)
            showOrHidePersistentFormatter(isPresent: true)
            return
        }

        updateInlineFormatterFrame(inlineFormatter, with: node)
    }

    internal func detectFormatterType() {
        guard let node = focussedWidget as? TextNode else { return }

        let selectedTextRange = node.selectedTextRange
        let cursorPosition = rootNode.cursorPosition
        let beginPosition = selectedTextRange.lowerBound == 0 ? cursorPosition..<cursorPosition + 1 : cursorPosition - 1..<cursorPosition
        let endPosition = cursorPosition..<cursorPosition + 1
        let range = selectedTextRange.lowerBound == 0 && selectedTextRange.upperBound > 0 ? beginPosition : endPosition
        var types: [FormatterType] = []

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

    internal func updateFormatterView(with type: FormatterType, attribute: BeamText.Attribute? = nil, kind: ElementKind? = .bullet) {
        guard let node = focussedWidget as? TextNode else { return }

        var hasAttribute = false

        if let attribute = attribute {
            hasAttribute = rootNode.state.attributes.contains(attribute)
        }

        if type == .h1 && node.element.kind == .heading(1) ||
           type == .h2 && node.element.kind == .heading(2) ||
           type == .quote && node.element.kind == .quote(1, "", "") ||
           type == .code && node.element.kind == .code {
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
        node.element.kind = isActive ? .bullet : kind
    }

    private func updateAttributeState(with node: TextNode, attribute: BeamText.Attribute, isActive: Bool) {
        let attributes = rootNode.state.attributes

        if rootNode.textIsSelected {
            isActive ?
                node.text.removeAttributes([attribute], from: node.selectedTextRange) :
                node.text.addAttributes([attribute], to: node.selectedTextRange)
        }

        guard let index = attributes.firstIndex(of: attribute),
              attributes.contains(attribute), isActive else {
            rootNode.state.attributes.append(attribute)
            return
        }

        rootNode.state.attributes.remove(at: index)
    }

    private func setActiveFormatters(_ types: [FormatterType]) {
        if let inlineFormatter = inlineFormatter {
            inlineFormatter.setActiveFormmatters(types)
        }

        if let persistentFormatter = persistentFormatter {
            persistentFormatter.setActiveFormmatters(types)
        }
    }

    private func updateInlineFormatterFrame(_ view: FormatterView, with node: TextNode, isPresent: Bool = false) {
        let (xOffset, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)
        let globalOffset = self.convert(node.offsetInDocument, to: nil)
        let yPos = globalOffset.y - rect.maxY

        if isPresent && isInlineFormatterHidden {
            view.frame.origin.y = yPos + 20
        } else if !isPresent && !isInlineFormatterHidden {
            view.frame.origin.y = yPos
        } else {
            view.frame = NSRect(
                x: xOffset + BeamTextEdit.xPosInlineFormatter,
                y: isPresent ? yPos + 20 : yPos,
                width: view.idealSize.width,
                height: view.idealSize.height
            )
        }
    }

    private func addConstraint(to view: FormatterView, with contentView: NSView) {
        BeamTextEdit.bottomAnchor = view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: BeamTextEdit.startBottomConstraint)
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
