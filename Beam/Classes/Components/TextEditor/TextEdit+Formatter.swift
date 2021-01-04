//
//  TextEdit+Formatter.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let viewWidth: CGFloat = 33.45
    private static let viewHeight: CGFloat = 32
    private static let xAnchorConstraint: CGFloat = 16.725
    private static let bottomAnchorConstraint: CGFloat = 50
    private static let formatterType: [FormatterType] = FormatterType.all

    // MARK: - UI
    internal func initFormatterView() {
        formatterView = FormatterView(frame: formatterViewRect())

        guard let formatterView = formatterView,
              let view = window?.contentView else { return }

        formatterView.items = BeamTextEdit.formatterType
        let button = NSButton(frame: NSRect(x: 200, y: 200, width: 40, height: 40))
        let image = NSImage(named: "editor-format_h1")

        button.isBordered = false
        button.image = image
        button.action = #selector(testAction(_:))
        addSubview(button)

        view.addSubview(formatterView)
    }

    @objc func testAction(_ sender: NSButton) {
        print("hello")
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
            y: window.frame.height - BeamTextEdit.bottomAnchorConstraint,
            width: BeamTextEdit.viewWidth * formatterSize,
            height: BeamTextEdit.viewHeight)
    }

}
