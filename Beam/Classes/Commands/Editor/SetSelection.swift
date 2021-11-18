//
//  SetSelection.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/03/2021.
//

import Foundation
import BeamCore

class SetSelection: TextEditorCommand {
    static let name: String = "SetSelection"

    var selection: Range<Int>
    var oldSelection: Range<Int>?

    init(_ selection: Range<Int>) {
        self.selection = selection
        super.init(name: Self.name)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func run(context: Widget?) -> Bool {
        oldSelection = context?.root?.selectedTextRange
        context?.root?.selectedTextRange = selection

        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let oldSelection = oldSelection else { return false }
        context?.root?.selectedTextRange = oldSelection
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let setSelection = command as? SetSelection
        else { return false }
        selection = setSelection.selection
        return true
    }
}

class CancelSelection: TextEditorCommand {
    static let name: String = "CancelSelection"

    var oldSelection: Range<Int>?
    var oldCursorPosition: Int?

    init() {
        super.init(name: Self.name)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func run(context: Widget?) -> Bool {
        oldSelection = context?.root?.selectedTextRange
        oldCursorPosition = context?.root?.cursorPosition
        context?.root?.cancelSelection(.current)

        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let oldSelection = oldSelection,
              let oldCursorPosition = oldCursorPosition
        else { return true }
        context?.root?.selectedTextRange = oldSelection
        context?.root?.cursorPosition = oldCursorPosition
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        return command as? CancelSelection != nil
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func setSelection(_ node: TextNode, _ range: Range<Int>) -> Bool {
        return run(command: SetSelection(range), on: node)
    }

    @discardableResult
    func cancelSelection(_ node: TextNode) -> Bool {
        return run(command: CancelSelection(), on: node)
    }
}
