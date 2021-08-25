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
    var note: BeamNote? { element as? BeamNote }

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
                return caretIndex
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
            if let n = n {
                editor.onFocusChanged?(n.elementId, position)
            }
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
                    guard self._editor != nil else { return }
                    self.editor.setHotSpotToCursorPosition()
                }
            } else {
                self.editor.setHotSpotToCursorPosition()
            }
        }
        if let focused = focusedWidget as? ElementNode {
            focused.updateCursor()
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
    var debugSection: DebugSection?

    var otherSections: [Widget?] {
        [
            topSpacerWidget,
            linksSection,
            middleSpacerWidget,
            referencesSection,
            bottomSpacerWidget,
            browsingSection,
            debugSection
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

    override var idealSize: NSSize {
        super.updateRendering()
        computedIdealSize.height += self.idealSpacingSize
        return computedIdealSize
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element, nodeProvider: NodeProviderImpl(proxy: false))

        if let note = note {
            if !editor.journalMode {
                topSpacerWidget = SpacerWidget(parent: self, spacerType: .top)
            }
            linksSection = LinksSection(parent: self, note: note)
            middleSpacerWidget = SpacerWidget(parent: self, spacerType: .middle)
            referencesSection = ReferencesSection(parent: self, note: note)
            bottomSpacerWidget = SpacerWidget(parent: self, spacerType: .bottom)
            if Self.showBrowsingSection {
                browsingSection = BrowsingSection(parent: self, note: note)
            }
            if PreferencesManager.showDebugSection {
                debugSection = DebugSection(parent: self, note: note)
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
            first?.placeholder = BeamText(text: BeamPlaceholder.allPlaceholders.randomElement() ?? "Hello World !")
        }

        childInset = 0

        referencesSection?.open = false

        if !editor.journalMode {
            focus(widget: children.first ?? self, position: nil)
            focusedWidget = nodeFor(element.children.first ?? element, withParent: self)
            focusedWidget?.onFocus()
        }
        self.layer.backgroundColor = NSColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1.0).cgColor

    }

    override func setupAccessibility() {
        setAccessibilityLabel("TextRoot")
        setAccessibilityRole(.unknown)
        setAccessibilityParent(editor)
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

    private var breadCrumbs: [BeamNoteReference: BreadCrumb] = [:]
    func getBreadCrumb(for noteReference: BeamNoteReference) -> BreadCrumb? {
        guard let breadCrumb = breadCrumbs[noteReference] else {
            guard let referencingNote = BeamNote.fetch(DocumentManager(), id: noteReference.noteID) else { return nil }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else { return nil }
            let breadCrumb = BreadCrumb(parent: self, element: referencingElement)
            breadCrumbs[noteReference] = breadCrumb
            return breadCrumb
        }
        return breadCrumb
    }

    override var isTreeBoundary: Bool { false }

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
        cmdManager.insertElement(newElement, inElement: parent.unproxyElement, afterElement: (caretIndex == 0 ? previous : node)?.unproxyElement)
        cmdManager.focus(newElement, in: node)
    }
}
