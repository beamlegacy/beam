//
//  TextRoot.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation
import AppKit

public struct TextState {
    var text = BeamText()
    var selectedTextRange: Range<Int> = 0..<0
    var markedTextRange: Range<Int> = 0..<0
    var cursorPosition: Int = 0

    var attributes: [BeamText.Attribute] = []

    var nodeSelection: NodeSelection?
}

public struct TextConfig {
    var editable: Bool = true
    var font: Font = Font.system(size: 12)
    var keepCursorMidScreen = false //true

    var color = NSColor.textColor
    var disabledColor = NSColor.disabledControlTextColor
    var selectionColor = NSColor.editorTextSelectionColor
    var markedColor = NSColor.editorTextSelectionColor
    var alpha: Float = 1.0
    var blendMode: CGBlendMode = .normal

    var fHeight: Float { Float(font.ascent - font.descent) }
}

public class TextRoot: TextNode {
    @Published var textIsSelected = false

    var note: BeamNote?

    var state = TextState()

    private var _config = TextConfig()
    override var config: TextConfig { _config }
    override var selectedTextRange: Range<Int> {
        get {
            state.selectedTextRange
        }
        set {
            textIsSelected = !newValue.isEmpty
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
            assert(newValue >= 0)
            let n = focusedWidget as? TextNode
            let textCount = n?.element.text.count ?? 0
            state.cursorPosition = newValue > textCount ? textCount : newValue
            if state.selectedTextRange.isEmpty {
                state.selectedTextRange = newValue ..< newValue
            }
            updateTextAttributesAtCursorPosition()
            n?.invalidateText()
            focusedWidget?.invalidate()
            editor.reBlink()
            if state.nodeSelection == nil && !editor.scrollToCursorAtLayout {
                editor.setHotSpotToCursorPosition()
            }
        }
    }

    var selectedText: String {
        guard let node = focusedWidget as? TextNode else { return "" }
        return node.text.substring(range: selectedTextRange)
    }

    override var root: TextRoot {
        return self
    }

    var topSpacerWidget: SpacerWidget?
    var middleSpacerWidget: SpacerWidget?
    var bottomSpacerWidget: SpacerWidget?
    var linksSection: LinksSection?
    var referencesSection: LinksSection?
    var browsingSection: BrowsingSection?

    var otherSections: [Widget?] {
        [
            topSpacerWidget,
            linksSection,
            middleSpacerWidget,
            referencesSection,
            bottomSpacerWidget,
            browsingSection
        ]
    }
    override func buildTextChildren(elements: [BeamElement]) -> [Widget] {
        return super.buildTextChildren(elements: elements) + otherSections.compactMap { $0 }
    }

    weak var focusedWidget: Widget? {
        didSet {
            guard oldValue !== focusedWidget else { return }
            let oldNode = oldValue as? TextNode
            let newNode = focusedWidget as? TextNode
            oldValue?.onUnfocus()
            oldNode?.invalidateText()
            oldValue?.invalidate()
            focusedWidget?.onFocus()
            newNode?.invalidateText()
            focusedWidget?.invalidate()
            cancelSelection()
        }
    }

    weak var mouseHandler: Widget?

    override func invalidateLayout() {
        guard !needLayout else { return }
        super.invalidateLayout()
        editor.invalidateLayout()
        editor.invalidate()
    }

    override var offsetInRoot: NSPoint { NSPoint() }

    override func invalidate() {
        super.invalidate()
        editor.invalidate()
    }

    override init(editor: BeamTextEdit, element: BeamElement) {
        self.note = element as? BeamNote
        super.init(editor: editor, element: element)

        mapping[element] = WeakReference(self)
        if let note = note, note.type != .journal {
            topSpacerWidget = SpacerWidget(parent: self, spacerType: .top)
            linksSection = LinksSection(parent: self, note: note, mode: .links)
            middleSpacerWidget = SpacerWidget(parent: self, spacerType: .middle)
            referencesSection = LinksSection(parent: self, note: note, mode: .references)
            bottomSpacerWidget = SpacerWidget(parent: self, spacerType: .bottom)
            browsingSection = BrowsingSection(parent: self, note: note)
        }
        updateTextChildren(elements: element.children)

        self.selfVisible = false
        self.cursor = .arrow

        self.text = BeamText()

        // Main bullets:
        if element.children.isEmpty {
            // Create one empty initial bullet
            element.addChild(BeamElement())
        }

        if element.children.count == 1 && element.children.first?.text.isEmpty ?? false {
            let istoday = note?.isTodaysNote ?? false
            let first = children.first as? TextNode
            first?.placeholder = BeamText(text: istoday ? "This is the journal, you can type anything here!" : "...")
        }

        focus(widget: children.first ?? self, cursorPosition: nil)
        childInset = 0

        setAccessibilityLabel("TextRoot")
        setAccessibilityRole(.unknown)
        setAccessibilityParent(editor)

        referencesSection?.open = false

        focusedWidget = nodeFor(element.children.first ?? element, withParent: self)
        focusedWidget?.onFocus()
    }

    public override func printTree(level: Int = 0) -> String {
        return String.tabs(level) + (note?.title ?? "<???>") + "\n" + children.prefix(children.count).reduce("", { result, child -> String in
            result + child.printTree(level: level + 1)
        })
    }

    override var fullStrippedText: String {
        children.prefix(children.count).reduce(attributedString.string) { partial, node -> String in
            guard let node = node as? TextNode else { return partial }
            return partial + " " + node.fullStrippedText
        }
    }

    func focus(widget: Widget, cursorPosition newPosition: Int? = 0) {
        self.focusedWidget = widget
        if let position = newPosition {
            self.cursorPosition = position
        }
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

    override func dumpWidgetTree(_ level: Int = 0) {
        Logger.shared.logDebug("==================================================")
        super.dumpWidgetTree(level)
    }

    override var showDisclosureButton: Bool {
        false
    }

    override var mainLayerName: String {
        guard let note = note else {
            return "TextRoot - \(element.id.uuidString)"

        }
        return "TextRoot - [\(note.title)] - \(element.id.uuidString)"
    }

    public override func accessibilityFrameInParentSpace() -> NSRect {
        // We are flipped, but the accessibility framework ignores it so we need to change that by hand:
        return NSRect(origin: CGPoint(), size: editor.frame.size)
    }

    // Mapping of elements to nodes and breadcrumbs:
    override func nodeFor(_ element: BeamElement) -> TextNode? {
        return mapping[element]?.ref
    }

    override func nodeFor(_ element: BeamElement, withParent: Widget) -> TextNode {
        if let node = mapping[element]?.ref {
            return node
        }

        let node: TextNode = {
            guard let note = element as? BeamNote else {
                guard element.note == nil || element.note == self.note else {
                    return LinkedReferenceNode(parent: withParent, element: element)
                }
                return TextNode(parent: withParent, element: element)
            }
            return TextRoot(editor: editor, element: note)
        }()

        accessingMapping = true
        mapping[element] = WeakReference(node)
        accessingMapping = false
        purgeDeadNodes()

        if let w = editor.window {
            node.contentsScale = w.backingScaleFactor
        }

        editor.layer?.addSublayer(node.layer)

        return node
    }

    override func clearMapping() {
        mapping.removeAll()
        super.clearMapping()
    }

    private var accessingMapping = false
    private var mapping: [BeamElement: WeakReference<TextNode>] = [:]
    private var deadNodes: [TextNode] = []

    func purgeDeadNodes() {
        guard !accessingMapping else { return }
        for dead in deadNodes {
            removeNode(dead)
        }
        deadNodes.removeAll()
    }

    override func removeNode(_ node: TextNode) {
        guard !accessingMapping else {
            deadNodes.append(node)
            return
        }
        mapping.removeValue(forKey: node.element)
    }

    private var breadCrumbs: [NoteReference: BreadCrumb] = [:]
    func getBreadCrumb(for noteReference: NoteReference) -> BreadCrumb? {
        guard let breadCrumb = breadCrumbs[noteReference] else {
            guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteName) else { return nil }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else { return nil }
            let breadCrumb = BreadCrumb(parent: self, element: referencingElement)
            breadCrumbs[noteReference] = breadCrumb
            return breadCrumb
        }
        return breadCrumb
    }
}
