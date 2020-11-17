//
//  TextRoot.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation
import AppKit

public struct TextState {
    var text: String = ""
    var selectedTextRange: Range<Int> = 0..<0
    var markedTextRange: Range<Int> = 0..<0
    var cursorPosition: Int = -1
}

public struct TextConfig {
    var editable: Bool = true
    var font: Font = Font.system(size: 12)
    var contextualSyntax = true
    var keepCursorMidScreen = false //true

    var color = NSColor.textColor
    var disabledColor = NSColor.disabledControlTextColor
    var selectionColor = NSColor(named: "EditorTextSelectionColor")!
    var markedColor = NSColor(named: "EditorTextSelectionColor")!
    var alpha: Float = 1.0
    var blendMode: CGBlendMode = .normal

    var fHeight: Float { Float(font.ascent - font.descent) }

}

public class TextRoot: TextNode {
    var note: Note!
    var _coreDataManager: CoreDataManager
    override var coreDataManager: CoreDataManager {
        return _coreDataManager
    }

    var undoManager = UndoManager()
    var state = TextState()
    override var selectedTextRange: Range<Int> {
        get {
            state.selectedTextRange
        }
        set {
            state.selectedTextRange = newValue
        }
    }
    override var markedTextRange: Range<Int> {
        get {
            state.markedTextRange
        }
        set {
            state.markedTextRange = newValue
        }
    }
    override var cursorPosition: Int {
        get {
            state.cursorPosition
        }
        set {
            state.cursorPosition = newValue
            node.invalidateText()
            editor?.reBlink()
            editor?.setHotSpotToCursorPosition()
        }
    }

    var selectedText: String {
        return node.text.substring(range: selectedTextRange)
    }

    var _editor: BeamTextEdit?
    override var editor: BeamTextEdit? {
        return _editor
    }

    override var root: TextRoot {
        return self
    }

    private lazy var _config = { TextConfig() }()
    override var config: TextConfig {
        if let e = editor {
            return e.config
        }

        return _config
    }

    var node: TextNode! {
        didSet {
            oldValue.invalidateText()
            node.invalidateText()
            cancelSelection()
        }
    }

    override func invalidateLayout() {
        editor?.invalidateLayout()
    }

    override func invalidate(_ rect: NSRect? = nil) {
        if let r = rect {
            editor?.invalidate(r.offsetBy(dx: frame.minX, dy: frame.minY))
        } else {
            editor?.invalidate(frame)
        }
    }

    init(_ manager: CoreDataManager, note: Note) {
        self._coreDataManager = manager
        super.init(bullet: nil, recurse: false)
        self.note = note
        self.selfVisible = false

        self.text = ""

        // Main bullets:
        if note.rootBullets().isEmpty {
            // Create one empty initial bullet
            _ = note.createBullet(manager.mainContext, content: "")
        }

        for bullet in note.rootBullets() {
            addChild(TextNode(bullet: bullet, recurse: true))
        }

        children.first?.placeholder = (note.type == NoteType.journal.rawValue && note === AppDelegate.main.data.todaysNote) ? "This is the journal, you can type anything here!" : "..."

        if let linkedRefs = note.linkedReferences, !linkedRefs.isEmpty {
            let node = TextNode(staticText: "Linked references")
            node.isReference = true
            node.readOnly = true
            addChild(node)
            for bullet in linkedRefs {
                node.addChild(TextNode(bullet: bullet, recurse: true))
            }
            linkedRefsNode = node
        }

        if let unlinkedRefs = note.unlinkedReferences, !unlinkedRefs.isEmpty {
            let node = TextNode(staticText: "Unlinked references")
            node.isReference = true
            node.readOnly = true
            addChild(node)
            for bullet in unlinkedRefs {
                node.addChild(TextNode(bullet: bullet, recurse: true))
            }
            unlinkedRefsNode = node
        }

        node = children.first ?? self
        childInset = 0

        print("created RootNode \(note.title) with \(children.count) main bullets")
    }

    var linkedRefsNode: TextNode?
    var unlinkedRefsNode: TextNode?

    public override func printTree(level: Int = 0) -> String {
        return String.tabs(level) + note.title + "\n" + children.reduce("", { result, child -> String in
            result + child.printTree(level: level + 1)
        })
    }

    func focus(node: TextNode) {
        self.node = node
        cursorPosition = 0
    }

    var lastCommand: TextRoot.Command = .none

    let commands: [Command: CommandDefinition] = [
        .none: CommandDefinition(undo: false, redo: false, coalesce: false, name: ""),
        .insertText: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Insert Text"),
        .moveForward: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Forward"),
        .moveRight: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Right"),
        .moveBackward: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Right"),
        .moveLeft: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Left"),
        .moveUp: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Up"),
        .moveDown: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Down"),
        .moveWordForward: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Forward"),
        .moveWordBackward: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Backward"),
        .moveToBeginningOfLine: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move To Beginning Of Line"),
        .moveToEndOfLine: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move To End Of Line"),
        .centerSelectionInVisibleArea: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Center Selection In Visible Area"),
        .moveBackwardAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Backward And Modify Selection"),
        .moveForwardAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Forward And Modify Selection"),
        .moveWordForwardAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Forward And Modify Selection"),
        .moveWordBackwardAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Backward And Modify Selection"),
        .moveUpAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Up And Modify Selection"),
        .moveDownAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Down And Modify Selection"),
        .moveToBeginningOfLineAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move To Beginning Of Line And Modify Selection"),
        .moveToEndOfLineAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move To End Of Line And Modify Selection"),
        .moveWordRight: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Right"),
        .moveWordLeft: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Left"),
        .moveRightAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Right And Modify Selection"),
        .moveLeftAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Left And Modify Selection"),
        .moveWordRightAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Right And Modify Selection"),
        .moveWordLeftAndModifySelection: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Move Word Left And Modify Selection"),
        .selectAll: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Select All"),
        .selectLine: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Select Line"),
        .selectWord: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Select Word"),
        .insertTab: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Insert Tab"),
        .insertNewline: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Insert New Line"),
        .deleteForward: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Delete Forward"),
        .deleteBackward: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Delete Backward"),
        .deleteWordForward: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Delete Word Forward"),
        .deleteWordBackward: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Delete Word Backward"),
        .deleteToBeginningOfLine: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Delete To Begining Of Line"),
        .deleteToEndOfLine: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Delete To End Of Line"),
        .complete: CommandDefinition(undo: true, redo: true, coalesce: true, name: "Complete"),
        .cancelOperation: CommandDefinition(undo: false, redo: false, coalesce: false, name: "Cancel Operation")
    ]
}
