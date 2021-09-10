//
//  CheckBoxTableCellView.swift
//  Beam
//
//  Created by Remi Santos on 01/04/2021.
//

import Foundation

class CheckBoxButton: NSButton {
    var checked: Bool {
        get { return state == .on }
        set { state = newValue ? .on : .off }
    }

    var mixedState: Bool {
        get { return state == .mixed }
        set { state = newValue ? .mixed : .off }
    }
}

class CheckBoxTableCellView: NSTableCellView {
    private var checkBox: CheckBoxButton!
    var checked: Bool {
        get { checkBox.checked }
        set { checkBox.checked = newValue }
    }
    var onCheckChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        checkBox = CheckBoxButton(checkboxWithTitle: "", target: self, action: #selector(onCheck(_:)))
        checkBox.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(checkBox)
        self.addConstraints([
            leadingAnchor.constraint(equalTo: checkBox.leadingAnchor),
            trailingAnchor.constraint(equalTo: checkBox.trailingAnchor),
            topAnchor.constraint(equalTo: checkBox.topAnchor),
            bottomAnchor.constraint(equalTo: checkBox.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onCheck(_ sender: CheckBoxButton) {
        onCheckChange?(sender.checked)
    }
}

class CheckBoxTableHeaderCell: TableHeaderCell {
    private var checkBox: CheckBoxButton!
    var checked: Bool {
        get { checkBox.checked }
        set { checkBox.checked = newValue }
    }
    override init(textCell: String) {
        super.init(textCell: textCell)
        checkBox = CheckBoxButton(checkboxWithTitle: "", target: self, action: #selector(onCheck(_:)))
        checkBox.isEnabled = true
        checkBox.checked = false

        drawsBottomBorder = false
        drawsTrailingBorder = false
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // we don't need anything drawn
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onCheck(_ sender: CheckBoxButton) {
        // check toggle will be handled by TableView's mouseDownInHeaderOf
    }
}
