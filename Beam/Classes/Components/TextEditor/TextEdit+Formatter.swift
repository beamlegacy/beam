//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let viewWidth: CGFloat = 40.5
    private static let viewHeight: CGFloat = 32
    private static let xAnchorConstraint: CGFloat = 20.25
    private static let startBottomConstraint: CGFloat = -35
    private static let bottomConstraint: CGFloat = 25
    private static let formatterType: [FormatterType] = [.h1, .h2, .quote, .code, .bold, .italic, .strikethrough]
    private static var formatterIsInit = false
    private static var formatterIsHidden = false

    // MARK: - UI
    internal func initFormatterView() {
        guard formatterView == nil else {
            showOrHideFormatterView(isPresent: true)
            return
        }

        formatterView = FormatterView(frame: formatterViewRect(BeamTextEdit.startBottomConstraint))

        guard let formatterView = formatterView,
              let view = window?.contentView else { return }

        view.addSubview(formatterView)

        formatterView.items = BeamTextEdit.formatterType
        formatterView.didSelectFormatterType = { [unowned self] (type, isActive) -> Void in
            selectFormatterAction(type, isActive)
        }

        BeamTextEdit.formatterIsInit = true
        showOrHideFormatterView(isPresent: true)
    }

    internal func updateFormatterViewLayout() {
        if !BeamTextEdit.formatterIsInit && !BeamTextEdit.formatterIsHidden {
            formatterView?.frame = formatterViewRect()
        }
    }

    // MARK: - Methods
    internal func dismissFormatterView() {
        guard formatterView != nil else { return }
        formatterView?.removeFromSuperview()
        formatterView = nil
    }

    internal func showOrHideFormatterView(isPresent: Bool) {
        guard let formatterView = formatterView else { return }

        DispatchQueue.main.async { [unowned self] in
            NSAnimationContext.runAnimationGroup ({ ctx in
                ctx.allowsImplicitAnimation = true
                ctx.duration = 0.3

                formatterView.frame = formatterViewRect(isPresent ? BeamTextEdit.bottomConstraint : BeamTextEdit.startBottomConstraint)
                BeamTextEdit.formatterIsInit = BeamTextEdit.formatterIsInit ? false : true
                BeamTextEdit.formatterIsHidden = isPresent ? false : true
            }, completionHandler: nil)
        }
    }

    internal func detectFormatterType() {
        guard let node = node as? TextNode,
              let formatterView = formatterView else { return }

        let range = rootNode.cursorPosition <= 0 ? rootNode.cursorPosition..<rootNode.cursorPosition + 1 : rootNode.cursorPosition - 1..<rootNode.cursorPosition
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
        guard let formatterView = formatterView,
              let node = node as? TextNode else { return }

        var hasAttribute = false

        if let attribute = attribute {
            hasAttribute = rootNode.state.attributes.contains(attribute)
        }

        if type == .h1 && node.element.kind == .heading(1) ||
           type == .h1 && node.element.kind == .heading(2) ||
           type == .quote && node.element.kind == .quote(1, node.text.text, node.text.text) {
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

    private func formatterViewRect(_ y: CGFloat = bottomConstraint) -> NSRect {
        guard let window = window else { return NSRect.zero }
        let formatterSize = CGFloat(BeamTextEdit.formatterType.count)

        return NSRect(
            x: (window.frame.width / 2) - (BeamTextEdit.xAnchorConstraint * formatterSize),
            y: y,
            width: BeamTextEdit.viewWidth * formatterSize,
            height: BeamTextEdit.viewHeight)
    }

}
