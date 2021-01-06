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
    private static let bottomAnchorConstraint: CGFloat = 25
    private static let formatterType: [FormatterType] = FormatterType.all

    // MARK: - UI
    internal func initFormatterView() {
        formatterView = FormatterView(frame: formatterViewRect())

        guard let formatterView = formatterView,
              let view = window?.contentView else { return }

        formatterView.items = BeamTextEdit.formatterType
        formatterView.didSelectFormatterType = { [unowned self] (type) -> Void in
            self.selectFormatterAction(type)
        }

        view.addSubview(formatterView)
    }

    internal func updateFormatterViewLayout() {
        formatterView?.frame = self.formatterViewRect()
    }

    internal func dismissFormatterView() {
        guard formatterView != nil else { return }
        formatterView?.removeFromSuperview()
        formatterView = nil
    }

    // MARK: - Methods
    private func formatterViewRect() -> NSRect {
        guard let window = window else { return NSRect.zero }
        let formatterSize = CGFloat(BeamTextEdit.formatterType.count)

        return NSRect(
            x: (window.frame.width / 2) - (BeamTextEdit.xAnchorConstraint * formatterSize),
            y: BeamTextEdit.bottomAnchorConstraint,
            width: BeamTextEdit.viewWidth * formatterSize,
            height: BeamTextEdit.viewHeight)
    }

    // swiftlint:disable cyclomatic_complexity
    private func selectFormatterAction(_ type: FormatterType) {
        switch type {
        case .h1:
            print("h1")
        case .h2:
            print("h2")
        case .bullet:
            print("bullet")
        case .numbered:
            print("numbered")
        case .quote:
            print("quote")
        case .checkmark:
            print("checkmark")
        case .italic:
            print("italic")
        case .strikethrough:
            print("strikethrough")
        case .link:
            print("link")
        case .code:
            print("code")
        }
    }

}
