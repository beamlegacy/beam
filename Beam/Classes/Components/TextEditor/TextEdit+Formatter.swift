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
    private static let formatterType: [FormatterType] = FormatterType.all
    private static var formatterIsInit = false

    // MARK: - UI
    internal func initFormatterView() {

        guard formatterView == nil else {
            self.showFormatterViewWithAnimation()
            return
        }

        formatterView = FormatterView(frame: formatterViewRect(0))

        guard let formatterView = formatterView,
              let view = window?.contentView else { return }

        view.addSubview(formatterView)

        formatterView.items = BeamTextEdit.formatterType
        formatterView.didSelectFormatterType = { [unowned self] (type) -> Void in
            self.selectFormatterAction(type)
        }

        BeamTextEdit.formatterIsInit = true
    }

    internal func updateFormatterViewLayout() {
        if !BeamTextEdit.formatterIsInit { formatterView?.frame = self.formatterViewRect() }

        if BeamTextEdit.formatterIsInit {
            self.showFormatterViewWithAnimation()
        }
    }

    internal func dismissFormatterView() {
        guard formatterView != nil else { return }
        self.formatterView?.removeFromSuperview()
        self.formatterView = nil
    }

    internal func dismissFormatterViewWithAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSAnimationContext.runAnimationGroup ({ (ctx) in
                ctx.allowsImplicitAnimation = true
                ctx.duration = 0.3

                self.formatterView?.frame = self.formatterViewRect(BeamTextEdit.startBottomConstraint)
            }, completionHandler: {[weak self] in
                guard let self = self else { return }
                self.dismissFormatterView()
            })
        }
    }

    // MARK: - Methods
    private func formatterViewRect(_ y: CGFloat = bottomConstraint) -> NSRect {
        guard let window = window else { return NSRect.zero }
        let formatterSize = CGFloat(BeamTextEdit.formatterType.count)

        return NSRect(
            x: (window.frame.width / 2) - (BeamTextEdit.xAnchorConstraint * formatterSize),
            y: y,
            width: BeamTextEdit.viewWidth * formatterSize,
            height: BeamTextEdit.viewHeight)
    }

    private func showFormatterViewWithAnimation() {
        guard let formatterView = formatterView else { return }

        DispatchQueue.main.async { [unowned self] in
            NSAnimationContext.runAnimationGroup ({ (ctx) in
                ctx.allowsImplicitAnimation = true
                ctx.duration = 0.3

                formatterView.frame = formatterViewRect(BeamTextEdit.bottomConstraint)
            }, completionHandler: {
                BeamTextEdit.formatterIsInit = false
            })
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func selectFormatterAction(_ type: FormatterType) {
        guard let node = node as? TextNode else { return }

        switch type {
        case .h1:
            changeTextFormat(with: node, attributes: .heading(1))
        case .h2:
            changeTextFormat(with: node, attributes: .heading(2))
        case .bullet:
            print("bullet")
        case .numbered:
            print("numbered")
        case .quote:
            print("quote")
        case .checkmark:
            print("checkmark")
        case .bold:
            changeTextFormat(with: node, attributes: .strong)
        case .italic:
            changeTextFormat(with: node, attributes: .emphasis)
        case .strikethrough:
            print("strikethrough")
        case .link:
            changeTextFormat(with: node, attributes: .link(node.text.text))
        case .code:
            print("code")
        default:
            break
        }
    }

    private func changeTextFormat(with node: TextNode, attributes: BeamText.Attribute) {
        let text = node.text.text
        node.text.toggle(attribute: attributes, forRange: cursorStartPosition..<rootNode.cursorPosition + text.count)
    }

}
