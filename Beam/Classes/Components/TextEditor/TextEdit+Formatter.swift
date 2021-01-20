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
    private static let xAnchorConstraint: CGFloat = 20.25
    private static let startBottomConstraint: CGFloat = 35
    private static let bottomConstraint: CGFloat = -25
    private static let inlineFormatterType: [FormatterType] = [.h1, .h2, .bullet, .checkmark, .bold, .italic, .link]
    private static let persistentFormatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]

    private static var topAnchor: NSLayoutConstraint?
    private static var bottomAnchor: NSLayoutConstraint?
    private static var leftAnchor: NSLayoutConstraint?
    private static var centerXAnchor: NSLayoutConstraint?
    private static var widthAnchor: NSLayoutConstraint?
    private static var heightAnchor: NSLayoutConstraint?

    // MARK: - UI
    internal func initFormatterView() {
        guard persistentFormatter == nil else {
            presentPersistentFormatter(isPresent: true)
            return
        }

        persistentFormatter = FormatterView(viewType: .persistent)

        guard let persistentFormatter = persistentFormatter,
              let view = window?.contentView else { return }

        persistentFormatter.translatesAutoresizingMaskIntoConstraints = false

        BeamTextEdit.bottomAnchor = persistentFormatter.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: BeamTextEdit.startBottomConstraint)
        BeamTextEdit.centerXAnchor = persistentFormatter.centerXAnchor.constraint(equalTo: view.centerXAnchor)

        view.addSubview(persistentFormatter)

        guard let bottomAnchor = BeamTextEdit.bottomAnchor,
            let centerXAnchor = BeamTextEdit.centerXAnchor else { return }

        persistentFormatter.items = BeamTextEdit.persistentFormatterType
        persistentFormatter.didSelectFormatterType = { [unowned self] (type, isActive) -> Void in
            selectFormatterAction(type, isActive)
        }

        NSLayoutConstraint.activate([
            bottomAnchor,
            persistentFormatter.widthAnchor.constraint(equalToConstant: (BeamTextEdit.viewWidth * CGFloat(BeamTextEdit.persistentFormatterType.count)) + (BeamTextEdit.padding * CGFloat(BeamTextEdit.persistentFormatterType.count))),
            persistentFormatter.heightAnchor.constraint(equalToConstant: 32),
            centerXAnchor
        ])

        presentPersistentFormatter(isPresent: true)
    }

    internal func initInlineFormatter() {
        inlineFormatter = FormatterView(viewType: .inline)

        guard let inlineFormatter = inlineFormatter,
              let view = window?.contentView else { return }

        inlineFormatter.translatesAutoresizingMaskIntoConstraints = false

        BeamTextEdit.topAnchor = inlineFormatter.topAnchor.constraint(equalTo: view.topAnchor)
        BeamTextEdit.leftAnchor = inlineFormatter.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0)

        view.addSubview(inlineFormatter)

        guard let topAnchor = BeamTextEdit.topAnchor,
              let leftAnchor = BeamTextEdit.leftAnchor else { return }

        NSLayoutConstraint.activate([
            topAnchor,
            leftAnchor,
            (inlineFormatter).widthAnchor.constraint(equalToConstant: (BeamTextEdit.viewWidth * CGFloat(BeamTextEdit.inlineFormatterType.count)) + (BeamTextEdit.padding * CGFloat(BeamTextEdit.inlineFormatterType.count))),
            (inlineFormatter).heightAnchor.constraint(equalToConstant: 32)
        ])

        inlineFormatter.items = BeamTextEdit.inlineFormatterType
        inlineFormatter.didSelectFormatterType = { [unowned self] (type, isActive) -> Void in
            selectFormatterAction(type, isActive)
        }
    }

    // MARK: - Methods
    internal func presentPersistentFormatter(isPresent: Bool) {
        guard let formatterView = persistentFormatter,
              let bottomAnchor = BeamTextEdit.bottomAnchor else { return }

        formatterView.wantsLayer = true
        formatterView.layoutSubtreeIfNeeded()

        bottomAnchor.isActive = true
        bottomAnchor.constant = isPresent ? BeamTextEdit.bottomConstraint : BeamTextEdit.startBottomConstraint

        NSAnimationContext.runAnimationGroup ({ ctx in
            ctx.allowsImplicitAnimation = true
            ctx.duration = 0.3

            formatterView.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }

    internal func updateInlineFormatterView() {
        guard let node = node as? TextNode,
              let inlineFormatter = inlineFormatter,
              let topAnchor = BeamTextEdit.topAnchor,
              let leftAnchor = BeamTextEdit.leftAnchor else { return }

        if !rootNode.isTextSelected {
            dismissFormatterView(inlineFormatter)
            return
        }

        let (xOffset, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)

        inlineFormatter.wantsLayer = true
        inlineFormatter.layoutSubtreeIfNeeded()

        leftAnchor.constant = xOffset
        topAnchor.constant = (node.offsetInDocument.y + rect.maxY) - 10
    }

    internal func detectFormatterType() {
        guard let node = node as? TextNode,
              let formatterView = persistentFormatter else { return }

        let startPosition = rootNode.cursorPosition..<rootNode.cursorPosition + 1
        let middleOrEndPosition = rootNode.cursorPosition - 1..<rootNode.cursorPosition
        let range = rootNode.cursorPosition <= 0 ? startPosition : middleOrEndPosition
        var types: [FormatterType] = []

        rootNode.state.attributes = []
        formatterView.setActiveFormmatters(types)

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

        formatterView.setActiveFormmatters(types)
    }

    internal func updatePersistentView(with type: FormatterType, attribute: BeamText.Attribute? = nil, kind: ElementKind? = .bullet) {
        guard let formatterView = persistentFormatter,
              let node = node as? TextNode else { return }

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
        formatterView.setActiveFormatter(type)
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
            inlineFormatter = nil
        }
    }

    private func changeTextFormat(with node: TextNode, kind: ElementKind, isActive: Bool) {
        node.element.kind = isActive ? .bullet : kind
    }

    private func updateAttributeState(with node: TextNode, attribute: BeamText.Attribute, isActive: Bool) {
        let attributes = rootNode.state.attributes

        guard let index = attributes.firstIndex(of: attribute),
              attributes.contains(attribute), isActive else {
            rootNode.state.attributes.append(attribute)
            return
        }

        rootNode.state.attributes.remove(at: index)
    }

}
