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
            showFormatterViewWithAnimation()
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
        showFormatterViewWithAnimation()
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

    internal func dismissFormatterViewWithAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSAnimationContext.runAnimationGroup ({ ctx in
                ctx.allowsImplicitAnimation = true
                ctx.duration = 0.3

                self.formatterView?.frame = self.formatterViewRect(BeamTextEdit.startBottomConstraint)
            }, completionHandler: {
                BeamTextEdit.formatterIsHidden = true
            })
        }
    }

    private func showFormatterViewWithAnimation() {
        guard let formatterView = formatterView else { return }

        DispatchQueue.main.async { [unowned self] in
            NSAnimationContext.runAnimationGroup ({ ctx in
                ctx.allowsImplicitAnimation = true
                ctx.duration = 0.3

                formatterView.frame = formatterViewRect(BeamTextEdit.bottomConstraint)
            }, completionHandler: {
                BeamTextEdit.formatterIsInit = false
                BeamTextEdit.formatterIsHidden = false
            })
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func selectFormatterAction(_ type: FormatterType, _ isActive: Bool) {
        guard let node = node as? TextNode else { return }

        switch type {
        case .h1:
            changeTextFormat(with: node, attributes: .heading(1), isActive: isActive)
            updateAttributeState(
                with: node,
                attribute: .heading(1),
                isActive: isActive
            )
        case .h2:
            changeTextFormat(with: node, attributes: .heading(2), isActive: isActive)
            updateAttributeState(
                with: node,
                attribute: .heading(2),
                isActive: isActive
            )
        case .quote:
            print("quote")
        case .code:
            print("code")
        case .bold:
            updateAttributeState(with: node, attribute: .strong, isActive: isActive)
        case .italic:
            updateAttributeState(with: node, attribute: .emphasis, isActive: isActive)
        case .strikethrough:
            print("strikethrough")
        default:
            break
        }
    }

    // TODO: Rename function
    private func changeTextFormat(with node: TextNode, attributes: BeamText.Attribute, isActive: Bool) {
        let text = node.text.text
        let range = cursorStartPosition..<rootNode.cursorPosition + text.count

        isActive ? node.text.removeAttributes([attributes], from: range) : node.text.addAttributes([attributes], to: range)
    }

    // TODO: Rename function
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
