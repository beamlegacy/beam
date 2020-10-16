//
//  TextEdit.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//  Copyright © 2020 Beam. All rights reserved.
//
// swiftlint:disable file_length

import Foundation
import AppKit
import SwiftUI
import Combine

public struct BTextEdit: NSViewRepresentable {
    var note: Note

    func createBullet(bullet: Bullet) -> TextNode {
        let node = TextNode()
        node.text = bullet.content?.filter({ (char) -> Bool in
            !char.isNewline
        }) ?? "<empty debug>"

//        print("MD: \(bullet.orderIndex) \(node.text)")
        for child in bullet.sortedChildren() {
            node.children.append(createBullet(bullet: child))
        }

        return node
    }

    func createNodeTree(editor: BeamTextEdit, note: Note) -> TextRoot {
        let root = TextRoot(editor: editor)
        let mainNode = TextNode()

        mainNode.text = note.title!
        root.children.append(mainNode)

        for child in note.rootBullets() {
            mainNode.children.append(createBullet(bullet: child))
        }

        return root
    }

    public func makeNSView(context: Context) -> BeamTextEdit {
        let v = BeamTextEdit(text: "", font: Font.main)

//        guard let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, "Beam App v1") else { return v }
        v.rootNode = createNodeTree(editor: v, note: note)

        return v
    }

    public func updateNSView(_ nsView: BeamTextEdit, context: Context) {
        print("display note: \(note)")
        nsView.rootNode = createNodeTree(editor: nsView, note: note)
        nsView.node = nsView.rootNode.children.first!
    }

    public typealias NSViewType = BeamTextEdit
}

struct TextState {
    let text: String
    let selectedTextRange: Range<Int>
    let markedTextRange: Range<Int>
    let cursorPosition: Int
}

class TextRoot: TextNode {
    override var text: String {
        get { "" }
        set {
            assert(false) // the rootNode can't have text contents, it's just a placeholder for the note's children
        }
    }

    var _editor: BeamTextEdit?
    override var editor: BeamTextEdit {
        return _editor!
    }

    override func invalidateLayout() {
        editor.invalidateLayout()
    }

    override init() {
    }

    init(editor: BeamTextEdit) {
        self._editor = editor
    }
}

// swiftlint:disable type_body_length
public class BeamTextEdit: NSView, NSTextInputClient {
    public init(text: String = "", font: Font = Font.main) {
        self.font = font
        selectedTextRange = 0..<0
        markedTextRange = 0..<0
        cursorPosition = 0
        rootNode = TextRoot()
        node = TextNode()
        super.init(frame: NSRect())
        createRoot(text: text)
        _inputContext = NSTextInputContext(client: self)

        initBlinking()
    }

    public init(text: String = "", font: Font = Font.main, color: NSColor) {
        self.font = font
        self.color = color
        selectedTextRange = 0..<0
        markedTextRange = 0..<0
        cursorPosition = 0
        rootNode = TextRoot()
        node = TextNode()
        super.init(frame: NSRect())
        createRoot(text: text)
        _inputContext = NSTextInputContext(client: self)

        initBlinking()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createRoot(text: String) {
        rootNode = TextRoot(editor: self)

        let node1 = TextNode()
        node1.text = text
        rootNode.children.append(node1)

//        let node2 = TextNode()
//        node2.text = "text 2"
//        node1.children.append(node2)
//
//        let node3 = TextNode()
//        node3.text = "text 3"
//        node1.children.append(node3)
//
//        let node4 = TextNode()
//        node4.text = text
//        rootNode.children.append(node4)

        node = rootNode.children.first!
    }

    var font: Font
    var minimumWidth: Float? = 1024
    var maximumWidth: Float?
    public var activated: () -> Void = { }
    public var activateOnLostFocus = true
    public var useFocusRing = false

    public var contextualSyntax = true

    let _undoManager = UndoManager()
    public override var undoManager: UndoManager? { _undoManager }

    var selectedTextRange: Range<Int> {
        didSet {
            assert(selectedTextRange.lowerBound != NSNotFound)
            assert(selectedTextRange.upperBound != NSNotFound)
            reBlink()
        }
    }
    var markedTextRange: Range<Int> {
        didSet {
            assert(selectedTextRange.lowerBound != NSNotFound)
            assert(selectedTextRange.upperBound != NSNotFound)
            reBlink()
        }
    }
    var cursorPosition: Int {
        didSet {
            assert(cursorPosition != NSNotFound)
            reBlink()
            setHotSpotToCursorPosition()
            if contextualSyntax {
                node.invalidateTextRendering()
            }
        }
    }

    var selectedText: String {
        return node.text.substring(range: selectedTextRange)
    }

    public override var frame: NSRect {
        didSet {
            rootNode.width = Float(frame.width)
        }
    }

    var animate = false { didSet {
        // TODO: implement animating the cursor
    }
    }

    var color = NSColor.textColor
    var disabledColor = NSColor.disabledControlTextColor
    var selectionColor = NSColor.selectedControlColor
    var markedColor = NSColor.unemphasizedSelectedTextColor
    var alpha: Float = 1.0
    var blendMode: CGBlendMode = .normal

    var hMargin: Float = 2 { didSet { invalidateLayout() } }
    var vMargin: Float = 0 { didSet { invalidateLayout() } }

    // This is the root node of what we are editing:
    var rootNode: TextRoot {
        didSet {
            rootNode._editor = self
            invalidateLayout()
            invalidate()
        }
    }

    // This is the node that the user is currently editing. It can be any node in the rootNode tree
    var node: TextNode {
        didSet {
            invalidate()
            cancelSelection()
        }
    }

    override public var intrinsicContentSize: NSSize {
        rootNode.updateTextRendering()
        return NSSize(width: CGFloat(minimumWidth!), height: rootNode.frame.size.height)
    }

    public func setHotSpot(_ spot: NSRect) {
        if let sv = superview as? NSScrollView {
            sv.scrollToVisible(spot)
        }
    }

    public func invalidateLayout() {
        invalidateIntrinsicContentSize()
    }

    public override func layout() {
        invalidateLayout()
        super.layout()
    }

    public func invalidate() {
        setNeedsDisplay(bounds)
    }

    // Text Input from AppKit:
    private var _inputContext: NSTextInputContext!
    public override var inputContext: NSTextInputContext? {
        return _inputContext
    }

    public func hasMarkedText() -> Bool {
        return !markedTextRange.isEmpty
    }

    public func setMarkedText(string: String, selectedRange: Range<Int>, replacementRange: Range<Int>) {
        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !markedTextRange.isEmpty {
            range = markedTextRange
        }

        if !self.selectedTextRange.isEmpty {
            range = self.selectedTextRange
        }

        node.text.replaceSubrange(node.text.range(from: range), with: string)
        cursorPosition = range.upperBound
        cancelSelection()
        markedTextRange = range
        if markedTextRange.isEmpty {
            markedTextRange = node.text.clamp(markedTextRange.lowerBound ..< (markedTextRange.upperBound + string.count))
        }
        self.selectedTextRange = markedTextRange
        cursorPosition = self.selectedTextRange.upperBound
        reBlink()
    }

    public func unmarkText() {
        markedTextRange = 0..<0
    }

    public func insertText(string: String, replacementRange: Range<Int>) {
        pushUndoState(.insertText)

        let c = string.count
        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !selectedTextRange.isEmpty {
            range = selectedTextRange
        }

        let r = node.text.range(from: range)
        node.text.replaceSubrange(r, with: string)
        cursorPosition = range.lowerBound + c
        cancelSelection()
        reBlink()
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        let r1 = rectAt(range.lowerBound)
        let r2 = rectAt(range.upperBound)
        return (r1.union(r2), range)
    }

    public var enabled = true

    @Published var hasFocus = false

    public override func becomeFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = true
        invalidate()
        return super.becomeFirstResponder()
    }

    public override func resignFirstResponder() -> Bool {
        blinkPhase = true
        cancelSelection()
        invalidate()
        if activateOnLostFocus {
            activated()
        }
        hasFocus = false
        return super.resignFirstResponder()
    }

    func pressEnter(_ option: Bool) {
        if option {
            doCommand(.insertNewline)
        } else {
            node.text.removeSubrange(node.text.range(from: selectedTextRange))
            cursorPosition = selectedTextRange.startIndex
            let splitText = node.text.substring(from: cursorPosition, to: node.text.count)
            node.text.removeLast(node.text.count - cursorPosition)
            let newNode = TextNode()
            newNode.text = splitText
            newNode.children = node.children
            node.parent?.insert(node: newNode, after: node)
            cursorPosition = 0
            node = newNode
            cancelSelection()
        }
    }

    //swiftlint:disable cyclomatic_complexity
    //swiftlint:disable function_body_length
    override open func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        let command = event.modifierFlags.contains(.command)

        if self.hasFocus {
            if let k = event.specialKey {
                switch k {
                case .enter:
                    pressEnter(option)
                case .carriageReturn:
                    pressEnter(option)
                    return
                case .leftArrow:
                    if shift {
                        if option {
                            doCommand(.moveWordLeftAndModifySelection)
                        } else if command {
                            doCommand(.moveToBeginningOfLineAndModifySelection)
                        } else {
                            doCommand(.moveLeftAndModifySelection)
                        }
                        return
                    } else {
                        if option {
                            doCommand(.moveWordLeft)
                        } else if command {
                            doCommand(.moveToBeginningOfLine)
                        } else {
                            doCommand(.moveLeft)
                        }
                        return
                    }
                case .rightArrow:
                    if shift {
                        if option {
                            doCommand(.moveWordRightAndModifySelection)
                        } else if command {
                            doCommand(.moveToEndOfLineAndModifySelection)
                        } else {
                            doCommand(.moveRightAndModifySelection)
                        }
                        return
                    } else {
                        if option {
                            doCommand(.moveWordRight)
                        } else if command {
                            doCommand(.moveToEndOfLine)
                        } else {
                            doCommand(.moveRight)
                        }
                        return
                    }
                case .upArrow:
                    if shift {
                        doCommand(.moveUpAndModifySelection)
                        return
                    } else {
                        doCommand(.moveUp)
                        return
                    }
                case .downArrow:
                    if shift {
                        doCommand(.moveDownAndModifySelection)
                        return
                    } else {
                        doCommand(.moveDown)
                        return
                    }
                case .delete:
                    doCommand(.deleteBackward)
                    return
                default:
                    print("Special Key \(k)")
                }
            }

            switch event.keyCode {
            case 117: // delete
                doCommand(.deleteForward)
                return
            case 53: // escape
                cancelSelection()
                return
            default:
                break
            }

            if let ch = event.charactersIgnoringModifiers {
                switch ch {
                case "a":
                    if command {
                        doCommand(.selectAll)
                        return
                    }
                case "[":
                    if command {
                        doCommand(.decreaseIndentation)
                        return
                    }
                case "]":
                    if command {
                        doCommand(.increaseIndentation)
                        return
                    }
                default: break
                }
            }

        }
        inputContext?.handleEvent(event)
        //super.keyDown(with: event)
    }
    //swiftlint:enable cyclomatic_complexity
    //swiftlint:enable function_body_length

    func nodeAt(point: CGPoint) -> TextNode? {
        return rootNode.nodeAt(point: point)
    }

    func pushUndoState(_ command: Command) {
        guard let undoManager = undoManager else { return }
        defer {
            if !undoManager.isRedoing {
                lastCommand = command
            }
        }

        guard let commandDef = commands[command] else { return }
        guard commandDef.undo else { return }
        guard !(commandDef.coalesce && lastCommand == command) else { return }

        let state = TextState(text: self.node.text, selectedTextRange: selectedTextRange, markedTextRange: markedTextRange, cursorPosition: cursorPosition)
        undoManager.registerUndo(withTarget: self, handler: { (selfTarget) in
            if commandDef.redo {
                selfTarget.lastCommand = .none
                selfTarget.pushUndoState(command) // push the redo!
            }

            selfTarget.node.text = state.text
            selfTarget.selectedTextRange = state.selectedTextRange
            selfTarget.markedTextRange = state.markedTextRange
            selfTarget.cursorPosition = state.cursorPosition
        })
        undoManager.setActionName(commandDef.name)
    }

    var lastCommand: Command = .none
    struct CommandDefinition {
        var undo: Bool
        var redo: Bool
        var coalesce: Bool
        var name: String
    }

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

//    public var lineCount: Int { paragraphs.count }

    // Command system
    public enum Command {
        case none

        case insertText

        case moveForward
        case moveRight
        case moveBackward
        case moveLeft
        case moveUp
        case moveDown
        case moveWordForward
        case moveWordBackward
        case moveToBeginningOfLine
        case moveToEndOfLine

        case centerSelectionInVisibleArea

        case moveBackwardAndModifySelection
        case moveForwardAndModifySelection
        case moveWordForwardAndModifySelection
        case moveWordBackwardAndModifySelection
        case moveUpAndModifySelection
        case moveDownAndModifySelection

        case moveToBeginningOfLineAndModifySelection
        case moveToEndOfLineAndModifySelection

        case moveWordRight
        case moveWordLeft
        case moveRightAndModifySelection
        case moveLeftAndModifySelection
        case moveWordRightAndModifySelection
        case moveWordLeftAndModifySelection

        case selectAll
        case selectLine
        case selectWord

        case insertTab
        case insertNewline

        case increaseIndentation
        case decreaseIndentation

        case deleteForward
        case deleteBackward
        case deleteWordForward
        case deleteWordBackward
        case deleteToBeginningOfLine
        case deleteToEndOfLine

        case complete

        case cancelOperation
    }

    public func cancelSelection() {
        selectedTextRange = cursorPosition..<cursorPosition
        markedTextRange = selectedTextRange
        invalidate()
    }

    public func selectAll() {
        selectedTextRange = node.text.wholeRange
        cursorPosition = selectedTextRange.upperBound
        invalidate()
    }

    func eraseSelection() {
        if !selectedTextRange.isEmpty {
            node.text.removeSubrange(node.text.range(from: selectedTextRange))
            cursorPosition = selectedTextRange.lowerBound
            if cursorPosition == NSNotFound {
                cursorPosition = node.text.count
            }
            cancelSelection()
        }
    }

    //swiftlint:disable cyclomatic_complexity
    //swiftlint:disable function_body_length
    public func doCommand(_ command: Command) {
        pushUndoState(command)
        reBlink()
        switch command {
        case .moveForward:
            if selectedTextRange.isEmpty {
                cursorPosition = node.position(after: cursorPosition)
            }
            cancelSelection()

        case .moveLeft:
            if selectedTextRange.isEmpty {
                cursorPosition = node.position(before: cursorPosition)
            }
            cancelSelection()

        case .moveBackward:
            if selectedTextRange.isEmpty {
                cursorPosition = node.position(before: cursorPosition)
            }
            cancelSelection()

        case .moveRight:
            if selectedTextRange.isEmpty {
                cursorPosition = node.position(after: cursorPosition)
            }
            cancelSelection()

        case .moveLeftAndModifySelection:
            if cursorPosition != 0 {
                let newCursorPosition = node.position(before: cursorPosition)
                if cursorPosition == selectedTextRange.lowerBound {
                    selectedTextRange = node.text.clamp(newCursorPosition..<selectedTextRange.upperBound)
                } else {
                    selectedTextRange = node.text.clamp(selectedTextRange.lowerBound..<newCursorPosition)
                }
                cursorPosition = newCursorPosition
                invalidate()
            }

        case .moveWordRight:
            node.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.endIndex, options: .byWords) { (_, r1, _, stop) in
                self.cursorPosition = self.node.position(at: r1.upperBound)
                stop = true
            }

            cancelSelection()

        case .moveWordLeft:
            var range = node.text.startIndex ..< node.text.endIndex
            node.text.enumerateSubstrings(in: node.text.startIndex..<node.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
                range = r1
            }

            let pos = node.position(at: range.lowerBound)
            cursorPosition = pos == cursorPosition ? 0 : pos
            cancelSelection()

        case .moveWordRightAndModifySelection:
            var newCursorPosition = cursorPosition
            node.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.endIndex, options: .byWords) { (_, r1, _, stop) in
                newCursorPosition = self.node.position(at: r1.upperBound)
                stop = true
            }

            extendSelection(to: newCursorPosition)

        case .moveWordLeftAndModifySelection:
            var range = node.text.startIndex ..< node.text.endIndex
            let newCursorPosition = cursorPosition
            node.text.enumerateSubstrings(in: node.text.startIndex..<node.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
                range = r1
            }

            let pos = node.position(at: range.lowerBound)
            cursorPosition = pos == cursorPosition ? 0 : pos
            extendSelection(to: newCursorPosition)

        case .moveRightAndModifySelection:
            if cursorPosition != node.text.count {
                extendSelection(to: node.position(after: cursorPosition))
            }

        case .moveToBeginningOfLine:
            if let l = node.lineAt(index: cursorPosition) {
                cursorPosition = node.layouts[l].range.lowerBound
                cancelSelection()
            }

        case .moveToEndOfLine:
            if let l = node.lineAt(index: cursorPosition) {
                cursorPosition = node.layouts[l].range.upperBound - 1
                cancelSelection()
            }

        case .moveToBeginningOfLineAndModifySelection:
            if let l = node.lineAt(index: cursorPosition) {
                extendSelection(to: node.layouts[l].range.lowerBound)
            }

        case .moveToEndOfLineAndModifySelection:
            if let l = node.lineAt(index: cursorPosition) {
                extendSelection(to: node.layouts[l].range.upperBound - 1)
            }

        // TODO: Reimplement cursor movements in the tree
//        case .moveUp:
//            cursorPosition = positionAbove(cursorPosition)
//            cancelSelection()
//
//        case .moveDown:
//            cursorPosition = positionBelow(cursorPosition)
//            cancelSelection()
//
//        case .moveUpAndModifySelection:
//            extendSelection(to: positionAbove(cursorPosition))
//
//        case .moveDownAndModifySelection:
//            extendSelection(to: positionBelow(cursorPosition))

        case .increaseIndentation:
            if let p = node.parent {
                let replacementPos = node.indexInParent
                let newParent = TextNode()
                p.children[replacementPos] = newParent
                newParent.children.append(node)
            }

        case .decreaseIndentation:
            if let p = node.parent, p.parent != nil, p.children.count == 1, p.text.isEmpty {
                let replacementPos = p.indexInParent
                p.parent!.children[replacementPos] = node
            }

        case .selectAll:
            selectAll()

        case .deleteForward:
            if !selectedTextRange.isEmpty {
                node.text.removeSubrange(node.text.range(from: selectedTextRange))
                cursorPosition = selectedTextRange.lowerBound
                if cursorPosition == NSNotFound {
                    cursorPosition = node.text.count
                }
            } else if cursorPosition != node.text.count {
                node.text.remove(at: node.text.index(at: cursorPosition))
            }
            cancelSelection()

        case .deleteBackward:
            if !selectedTextRange.isEmpty {
                node.text.removeSubrange(node.text.range(from: selectedTextRange))
                cursorPosition = selectedTextRange.lowerBound
                if cursorPosition == NSNotFound {
                    cursorPosition = node.text.count
                }
                cancelSelection()
            } else if cursorPosition != 0 && node.text.count != 0 {
                cursorPosition = node.position(before: cursorPosition)
                node.text.remove(at: node.text.index(at: cursorPosition))
            }
            cancelSelection()

        case .insertNewline:
            if !selectedTextRange.isEmpty {
                node.text.removeSubrange(node.text.range(from: selectedTextRange))
                node.text.insert("\n", at: node.text.index(at: selectedTextRange.startIndex))
                cursorPosition = node.position(after: selectedTextRange.startIndex)
                if cursorPosition == NSNotFound {
                    cursorPosition = node.text.count
                }
                cancelSelection()
            } else if cursorPosition != 0 && node.text.count != 0 {
                node.text.insert("\n", at: node.text.index(at: cursorPosition))
                cursorPosition = node.position(after: cursorPosition)
            }
            cancelSelection()

        default:
            break
        }

        lastCommand = command
    }
    //swiftlint:enable cyclomatic_complexity
    //swiftlint:enable function_body_length

    func extendSelection(to newCursorPosition: Int) {
        var r1 = selectedTextRange.lowerBound
        var r2 = selectedTextRange.upperBound
        if cursorPosition == r2 {
            r2 = newCursorPosition
        } else {
            r1 = newCursorPosition
        }
        if r1 < r2 {
            selectedTextRange = node.text.clamp(r1..<r2)
        } else {
            selectedTextRange = node.text.clamp(r2..<r1)
        }
        cursorPosition = newCursorPosition
        invalidate()
    }

    // NSTextInputHandler:
    // NSTextInputClient:
    public func insertText(_ string: Any, replacementRange: NSRange) {
        //        print("insertText \(string) at \(replacementRange)")
        unmarkText()
        let range = replacementRange.lowerBound..<replacementRange.upperBound
        //swiftlint:disable:next force_cast
        insertText(string: string as! String, replacementRange: range)
    }

    /* The receiver inserts string replacing the content specified by replacementRange. string can be either an NSString or NSAttributedString instance. selectedRange specifies the selection inside the string being inserted; hence, the location is relative to the beginning of string. When string is an NSString, the receiver is expected to render the marked text with distinguishing appearance (i.e. NSTextView renders with -markedTextAttributes).
     */
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        //        print("setMarkedText \(string) at \(replacementRange) with selection \(selectedRange)")
        //swiftlint:disable:next force_cast
        let str = string as! String
        setMarkedText(string: str, selectedRange: selectedTextRange.lowerBound..<selectedTextRange.upperBound, replacementRange: replacementRange.lowerBound..<replacementRange.upperBound)
    }

    /* Returns the selection range. The valid location is from 0 to the document length.
     */
    public func selectedRange() -> NSRange {
        var r = NSRange()
        if selectedTextRange.isEmpty {
            r = NSRange(location: NSNotFound, length: 0)
        } else {
            r = NSRange(location: selectedTextRange.lowerBound, length: selectedTextRange.upperBound - selectedTextRange.lowerBound)
        }
        //        print("selectedRange \(r)")
        return r
    }

    /* Returns the marked range. Returns {NSNotFound, 0} if no marked range.
     */
    public func markedRange() -> NSRange {
        var r = NSRange()
        if markedTextRange.isEmpty {
            r = NSRange(location: NSNotFound, length: 0)
        } else {
            r = NSRange(location: markedTextRange.lowerBound, length: markedTextRange.upperBound - markedTextRange.lowerBound)
        }
        //        print("markedRange \(r)")
        return r
    }

    /* Returns attributed string specified by range. It may return nil. If non-nil return value and actualRange is non-NULL, it contains the actual range for the return value. The range can be adjusted from various reasons (i.e. adjust to grapheme cluster boundary, performance optimization, etc).
     */
    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        //        print("attributedSubstring for \(range)")
        if let ptr = actualRange {
            ptr.pointee = range
        }
        return node.attributedString.attributedSubstring(from: range)
    }

    public func attributedString() -> NSAttributedString {
        return NSAttributedString(string: node.text)
    }

    /* Returns an array of attribute names recognized by the receiver.
     */
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        //        print("validAttributesForMarkedText")
        return []
    }

    /* Returns the first logical rectangular area for range. The return value is in the screen coordinate. The size value can be negative if the text flows to the left. If non-NULL, actuallRange contains the character range corresponding to the returned area.
     */
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        //        print("firstRect for \(range)")
        let (rect, _) = firstRect(forCharacterRange: range.lowerBound..<range.upperBound)
        let p = convert(rect.origin, to: nil)
        let x = Float(p.x)
        let y = Float(p.y)
        var rc = NSRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(rect.width), height: CGFloat(rect.height))
        rc = convert(rc, to: nil)
        rc = window!.convertToScreen (rc)
        return rc
    }

    /* Returns the index for character that is nearest to point. point is in the screen coordinate system.
     */
    public func characterIndex(for point: NSPoint) -> Int {
        //        print("characterIndex for \(point)")
        return positionAt(point: point)
    }

    @IBAction func copy(_ sender: Any) {
        let s = selectedText
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(s, forType: .string)
    }

    @IBAction func cut(_ sender: Any) {
        let s = selectedText
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(s, forType: .string)
        eraseSelection()
    }

    @IBAction func undo(_ sender: Any) {
        undoManager?.undo()
    }

    @IBAction func redo(_ sender: Any) {
        undoManager?.redo()
    }

    @IBAction func paste(_ sender: Any) {
        if let s = NSPasteboard.general.string(forType: .string) {
            insertText(string: s, replacementRange: selectedTextRange)
        }
    }

    func initBlinking() {
        let defaults = UserDefaults.standard
        let von = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOn")
        onBlinkTime = von == 0 ? onBlinkTime : von * 1000
        let voff = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOff")
        offBlinkTime = voff == 0 ? offBlinkTime : voff * 1000
        self.animate = true
    }

    public func draw(in context: CGContext) {
        rootNode.width = Float(frame.width)
        rootNode.draw(in: context, width: Float(frame.width))
    }

    public override func draw(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current?.cgContext {
            self.draw(in: context)
        }
    }

    enum DragMode {
        case none
        case select(Int)
    }
    var dragMode = DragMode.none

    func reBlink() {
        blinkPhase = true
        blinkTime = CFAbsoluteTimeGetCurrent() + onBlinkTime
        invalidate()
    }

    var fHeight: Float { Float(font.ascent - font.descent) }

    public func lineAt(point: NSPoint) -> Int {
        let fid = node.frameInDocument
        return node.lineAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    public func positionAt(point: NSPoint) -> Int {
        let fid = node.frameInDocument
        return node.positionAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    override public func mouseDown(with event: NSEvent) {
        //       window?.makeFirstResponder(self)
        if event.clickCount == 1 {
            reBlink()
            let point = self.convert(event.locationInWindow, from: nil)
            guard let newNode = nodeAt(point: point) else { return }
            if newNode !== node {
                node = newNode
            }
            cursorPosition = positionAt(point: point)
            cancelSelection()
            dragMode = .select(cursorPosition)

        } else {
            doCommand(.selectAll)
        }
    }

    public func setHotSpotToCursorPosition() {
        setHotSpot(rectAt(cursorPosition))
    }

    public func rectAt(_ position: Int) -> NSRect {
        return node.rectAt(position)
    }

    override public func mouseDragged(with event: NSEvent) {
        //        window?.makeFirstResponder(self)
        let point = self.convert(event.locationInWindow, from: nil)
        let p = positionAt(point: point)
        cursorPosition = p
        switch dragMode {
        case .none:
            break
        case .select(let o):
            selectedTextRange = node.text.clamp(p < o ? cursorPosition..<o : o..<cursorPosition)
        }
        invalidate()
    }

    override public func mouseUp(with event: NSEvent) {
        dragMode = .none
        super.mouseUp(with: event)
    }

    public override var acceptsFirstResponder: Bool { true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let w = newWindow {
            w.acceptsMouseMovedEvents = true
        }
    }

    var onBlinkTime: Double = 0.7
    var offBlinkTime: Double = 0.5
    var blinkTime: Double = CFAbsoluteTimeGetCurrent()
    var blinkPhase = true

    //    func animate(_ tick: Tick) {
    //        let now = CFAbsoluteTimeGetCurrent()
    //        if blinkTime < now && hasFocus {
    //            blinkPhase.toggle()
    //            blinkTime = now + (blinkPhase ? onBlinkTime : offBlinkTime)
    //            invalidate()
    //        }
    //    }

    public override var isFlipped: Bool { true }
}
