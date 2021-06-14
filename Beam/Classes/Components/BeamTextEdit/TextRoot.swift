//
//  TextRoot.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation
import AppKit
import BeamCore

public struct TextState {
    var text = BeamText()
    var selectedTextRange: Range<Int> = 0..<0
    var markedTextRange: Range<Int>?
    var caretIndex: Int = 0

    var attributes: [BeamText.Attribute] = []

    var nodeSelection: NodeSelection?
}

public struct TextConfig {
    var editable: Bool = true
    var keepCursorMidScreen = false //true

    var color = BeamColor.Generic.text.nsColor
    var disabledColor = NSColor.disabledControlTextColor
    var cursorColor = BeamColor.Generic.cursor.nsColor
    var selectionColor = BeamColor.Generic.textSelection.nsColor
    var alpha: Float = 1.0
    var blendMode: CGBlendMode = .normal
}

public class TextRoot: TextNode {
    @Published var textIsSelected = false
    static var showBrowsingSection = false
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
    override var markedTextRange: Range<Int>? {
        get {
            state.markedTextRange
        }
        set {
            state.markedTextRange = newValue
        }
    }
    override var cursorPosition: Int {
        get {
            guard let n = focusedWidget as? TextNode else {
                return 0
            }
            return n.caretAtIndex(state.caretIndex).positionInSource
        }
        set {
            assert(newValue >= 0)
            let n = focusedWidget as? ElementNode
            let textCount = n?.textCount ?? 0
            let position = newValue > textCount ? textCount : newValue
            let caretIndex = n?.caretIndexForSourcePosition(position) ?? 0
            self.caretIndex = caretIndex
        }
    }

    func updateCursorPosition() {
        let n = focusedWidget as? TextNode
        if state.selectedTextRange.isEmpty {
            state.selectedTextRange = cursorPosition ..< cursorPosition
        }
        updateTextAttributesAtCursorPosition()
        n?.invalidateText()
        focusedWidget?.invalidate()
        editor.reBlink()
        n?.updateCursor()
        if state.nodeSelection == nil {
            if needLayout {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(10))) {
                    self.editor.setHotSpotToCursorPosition()
                }
            } else {
                self.editor.setHotSpotToCursorPosition()
            }
        }

    }
    override var caretIndex: Int {
        get {
            return state.caretIndex
        }
        set {
            state.caretIndex = newValue
            updateCursorPosition()
        }
    }

    var selectedText: String {
        guard let node = focusedWidget as? TextNode else { return "" }
        return node.text.substring(range: selectedTextRange)
    }

    override var root: TextRoot? {
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
        if let note = note {
            if !editor.journalMode {
                topSpacerWidget = SpacerWidget(parent: self, spacerType: .top)
            }
            linksSection = LinksSection(parent: self, note: note, mode: .links)
            middleSpacerWidget = SpacerWidget(parent: self, spacerType: .middle)
            referencesSection = LinksSection(parent: self, note: note, mode: .references)
            bottomSpacerWidget = SpacerWidget(parent: self, spacerType: .bottom)
            if Self.showBrowsingSection {
                browsingSection = BrowsingSection(parent: self, note: note)
            }
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

        if let isTodaysNote = note?.isTodaysNote, isTodaysNote && element.children.count == 1 && element.children.first?.text.isEmpty ?? false {
            let first = children.first as? TextNode
            first?.placeholder = BeamText(text: "You can write here and press ⌘⏎ to search the web")
        }

        childInset = 0

        setAccessibilityLabel("TextRoot")
        setAccessibilityRole(.unknown)
        setAccessibilityParent(editor)

        referencesSection?.open = false

        if !editor.journalMode {
            focus(widget: children.first ?? self, position: nil)
            focusedWidget = nodeFor(element.children.first ?? element, withParent: self)
            focusedWidget?.onFocus()
        }
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

    func focus(widget: Widget, position newPosition: Int? = 0) {
        self.focusedWidget = widget
        if let position = newPosition {
            self.cursorPosition = position
        }
    }

    var lastCommand: BeamTextEdit.Command = .none

    override func dumpWidgetTree(_ level: Int = 0) {
        //swiftlint:disable:next print
        print("==================================================")
        super.dumpWidgetTree(level)
    }

    override var showDisclosureButton: Bool {
        false
    }

    override var mainLayerName: String {
        guard let note = note else {
            return super.mainLayerName

        }
        return "TextRoot - [\(note.title)] - \(element.id.uuidString)"
    }

    public override func accessibilityFrameInParentSpace() -> NSRect {
        // We are flipped, but the accessibility framework ignores it so we need to change that by hand:
        return NSRect(origin: CGPoint(), size: editor.frame.size)
    }

    // Mapping of elements to nodes and breadcrumbs:
    override func nodeFor(_ element: BeamElement) -> ElementNode? {
        return mapping[element]?.ref
    }

    override func nodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode {
        if let node = mapping[element]?.ref {
            return node
        }

        let node: ElementNode = {
            guard let note = element as? BeamNote else {
                guard element.note == nil || element.note == self.note else {
                    return ProxyTextNode(parent: withParent, element: element)
                }

                switch element.kind {
                case .image:
                    return ImageNode(parent: withParent, element: element)
                case .embed:
                    return EmbedNode(parent: withParent, element: element)
                default:
                    return TextNode(parent: withParent, element: element)
                }
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

        editor.addToMainLayer(node.layer)

        return node
    }

    override func clearMapping() {
        mapping.removeAll()
        super.clearMapping()
    }

    private var accessingMapping = false
    private var mapping: [BeamElement: WeakReference<ElementNode>] = [:]
    private var deadNodes: [ElementNode] = []

    func purgeDeadNodes() {
        guard !accessingMapping else { return }
        for dead in deadNodes {
            removeNode(dead)
        }
        deadNodes.removeAll()
    }

    override func removeNode(_ node: ElementNode) {
        guard !accessingMapping else {
            deadNodes.append(node)
            return
        }
        mapping.removeValue(forKey: node.element)
    }

    private var breadCrumbs: [BeamNoteReference: BreadCrumb] = [:]
    func getBreadCrumb(for noteReference: BeamNoteReference) -> BreadCrumb? {
        guard let breadCrumb = breadCrumbs[noteReference] else {
            guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteTitle) else { return nil }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else { return nil }
            let breadCrumb = BreadCrumb(parent: self, element: referencingElement)
            breadCrumbs[noteReference] = breadCrumb
            return breadCrumb
        }
        return breadCrumb
    }

    override var cmdManager: CommandManager<Widget> {
        guard let note = note else { fatalError("Trying to access the command manager on an unconnected TextRoot is a programming error.") }
        return note.cmdManager
    }

    func insertElementNearNonTextElement(_ string: String = "") {
        insertElementNearNonTextElement(BeamText(text: string))
    }

    func insertElementNearNonTextElement(_ string: BeamText) {
        cmdManager.beginGroup(with: "Insert Element")
        defer { cmdManager.endGroup() }
        guard let node = focusedWidget as? ElementNode else { return }
        let newElement = BeamElement(string)
        let parent = node.parent as? ElementNode ?? node
        let previous = node.previousSibbling() as? ElementNode
        cmdManager.insertElement(newElement, in: parent, after: caretIndex == 0 ? previous : node)
        cmdManager.focus(newElement, in: node)
    }
}
