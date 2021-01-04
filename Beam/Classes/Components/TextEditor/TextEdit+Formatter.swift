//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let viewWidth: CGFloat = 368
    private static let viewHeight: CGFloat = 32
    private static let xAnchorConstraint: CGFloat = 184
    private static let bottomAnchorConstraint: CGFloat = 50

    // MARK: - UI
    internal func initFormatterView() {
        formatterView = FormatterView(frame: formatterViewRect())

        guard let formatterView = formatterView,
              let view = window?.contentView else { return }

        formatterView.items = [.h1, .h2, .bullet]

        view.addSubview(formatterView)
    }

    internal func updateFormatterViewLayout() {
        formatterView?.frame = self.formatterViewRect()
    }

    internal func dismissFormatterView() {
        formatterView?.removeFromSuperview()
        formatterView = nil
    }

    // MARK: - Methods
    private func formatterViewRect() -> NSRect {
        guard let window = window else { return NSRect.zero }

        return NSRect(
            x: (window.frame.width / 2) - BeamTextEdit.xAnchorConstraint,
            y: window.frame.height - BeamTextEdit.bottomAnchorConstraint,
            width: BeamTextEdit.viewWidth,
            height: BeamTextEdit.viewHeight)
    }

}
