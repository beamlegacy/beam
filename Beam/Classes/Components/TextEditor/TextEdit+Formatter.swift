//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let viewWidth: CGFloat = 34
    private static let viewHeight: CGFloat = 32
    private static let padding: CGFloat = 1.45
    private static let xPosInlineFormatter: CGFloat = 55
    private static let startTopConstraint: CGFloat = 10
    private static let topConstraint: CGFloat = 12
    private static let startBottomConstraint: CGFloat = 35
    private static let bottomConstraint: CGFloat = -25
    private static let inlineFormatterType: [FormatterType] = [.h1, .h2, .bullet, .checkmark, .bold, .italic, .link]
    private static let persistentFormatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]

    private static var isSelectableContent = true
    private static var topAnchor: NSLayoutConstraint?
    private static var bottomAnchor: NSLayoutConstraint?
    private static var leftAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?

    // MARK: - UI
    internal func initFormatterView(_ viewType: FormatterViewType) {
        guard persistentFormatter == nil || inlineFormatter == nil else {
            showOrHidePersistentFormatter(isPresent: true)
            return
        }

        var view: FormatterView?

        if viewType == .persistent {
            persistentFormatter = FormatterView(viewType: .persistent)
            view = persistentFormatter
        } else {
            inlineFormatter = FormatterView(viewType: .inline)
            view = inlineFormatter
        }

        view?.alphaValue = 0

        guard let formatterView = view,
              let contentView = window?.contentView else { return }

        formatterView.translatesAutoresizingMaskIntoConstraints = false

        addConstraint(to: formatterView, with: contentView)
        contentView.addSubview(formatterView)
        activeLayoutConstraint(for: formatterView)

        formatterView.items = formatterView == persistentFormatter ? BeamTextEdit.persistentFormatterType : BeamTextEdit.inlineFormatterType
        formatterView.didSelectFormatterType = { [unowned self] (type, isActive) -> Void in
            selectFormatterAction(type, isActive)
        }

        if formatterView == persistentFormatter { showOrHidePersistentFormatter(isPresent: true) }
    }

    // MARK: - Methods
    internal func showOrHidePersistentFormatter(isPresent: Bool) {
        guard let persistentFormatter = persistentFormatter,
              let bottomAnchor = BeamTextEdit.bottomAnchor else { return }

        persistentFormatter.wantsLayer = true
        persistentFormatter.layoutSubtreeIfNeeded()

        bottomAnchor.constant = isPresent ? BeamTextEdit.bottomConstraint : BeamTextEdit.startBottomConstraint

        NSAnimationContext.runAnimationGroup ({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = isPresent ? 0.7 : 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.64, 0.4, 0, 0.98)

            persistentFormatter.alphaValue = isPresent ? 1 : 0
            persistentFormatter.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }

    internal func showOrHideInlineFormatter(isPresent: Bool) {
        guard let node = node as? TextNode,
              let inlineFormatter = inlineFormatter,
              let topAnchor = BeamTextEdit.topAnchor else { return }

        let (_, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)
        let yPos = (node.offsetInDocument.y + rect.maxY)

        inlineFormatter.wantsLayer = true
        inlineFormatter.layoutSubtreeIfNeeded()

        topAnchor.constant = isPresent ? yPos - BeamTextEdit.topConstraint : yPos + BeamTextEdit.topConstraint

        NSAnimationContext.runAnimationGroup ({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = isPresent ? 0.4 : 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.64, 0.4, 0, 0.98)

            inlineFormatter.alphaValue = isPresent ? 1 : 0
            isInlineFormatterHidden = false
            inlineFormatter.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            if !isPresent { self.dismissFormatterView(inlineFormatter) }
        })
    }

    internal func updateInlineFormatterView() {
        guard let node = node as? TextNode,
              let inlineFormatter = inlineFormatter,
              let topAnchor = BeamTextEdit.topAnchor,
              let leftAnchor = BeamTextEdit.leftAnchor else { return }

        detectFormatterType()

        if !rootNode.textIsSelected {
            showOrHideInlineFormatter(isPresent: false)
            showOrHidePersistentFormatter(isPresent: true)
            return
        }

        let (xOffset, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)
        let yPosition = (node.offsetInDocument.y + rect.maxY) - (isInlineFormatterHidden ? BeamTextEdit.startTopConstraint : BeamTextEdit.topConstraint)
        let currentLowerBound = currentTextRange.lowerBound
        let selectedLowLowerBound = node.selectedTextRange.lowerBound

        inlineFormatter.wantsLayer = true
        inlineFormatter.layoutSubtreeIfNeeded()

        leftAnchor.constant = xOffset + BeamTextEdit.xPosInlineFormatter

        if currentLowerBound == selectedLowLowerBound && BeamTextEdit.isSelectableContent {
            BeamTextEdit.isSelectableContent = false
            topAnchor.constant = yPosition
        }

        if currentLowerBound > selectedLowLowerBound {
            BeamTextEdit.isSelectableContent = true
            topAnchor.constant = yPosition
        }
    }

    internal func detectFormatterType() {
        guard let node = node as? TextNode else { return }

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
        guard let node = node as? TextNode else { return }

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
        guard let node = node as? TextNode else { return }

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

    private func addConstraint(to view: FormatterView, with contentView: NSView) {
        if view == persistentFormatter {
            BeamTextEdit.bottomAnchor = view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: BeamTextEdit.startBottomConstraint)
            BeamTextEdit.centerXAnchor = view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        } else {
            BeamTextEdit.topAnchor = view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0)
            BeamTextEdit.leftAnchor = view.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 0)
        }
    }

    private func activeLayoutConstraint(for view: FormatterView) {
        let formatterItemSize = view == persistentFormatter ? CGFloat(BeamTextEdit.persistentFormatterType.count) : CGFloat(BeamTextEdit.inlineFormatterType.count)

        let widthAnchor = view.widthAnchor.constraint(equalToConstant: (BeamTextEdit.viewWidth * formatterItemSize) + (BeamTextEdit.padding * formatterItemSize))
        let heightAnchor = view.heightAnchor.constraint(equalToConstant: BeamTextEdit.viewHeight)

        if view == persistentFormatter {
            guard let bottomAnchor = BeamTextEdit.bottomAnchor,
                  let centerXAnchor = BeamTextEdit.centerXAnchor else { return }

            NSLayoutConstraint.activate([
                bottomAnchor,
                widthAnchor,
                heightAnchor,
                centerXAnchor
            ])
        } else {
            guard let topAnchor = BeamTextEdit.topAnchor,
                  let leftAnchor = BeamTextEdit.leftAnchor else { return }

            NSLayoutConstraint.activate([
                topAnchor,
                leftAnchor,
                widthAnchor,
                heightAnchor
            ])
        }
    }
}
