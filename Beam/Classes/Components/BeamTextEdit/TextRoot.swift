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
    var selectedTextRange: Range<Int> = 0..<0
    var markedTextRange: Range<Int>?
    var caretIndex: Int = 0

    var attributes: [BeamText.Attribute] = []

    var nodeSelection: NodeSelection?
}

public struct TextConfig {
    var editable: Bool = true
    var keepCursorMidScreen = false //true

    var color = BeamColor.Generic.text.staticColor
    var disabledColor: CGColor = NSColor.disabledControlTextColor.cgColor
    var cursorColor: CGColor { BeamColor.Cursor.cache.cursor.cgColor }
    var selectionColor: CGColor { BeamColor.Cursor.cache.selection.cgColor }
    var alpha: Float = 1.0
    var blendMode: CGBlendMode = .normal
}

public class TextRoot: ElementNode {
    @Published var textIsSelected = false
    var note: BeamNote? { element as? BeamNote }

    var state = TextState()

    private var _config = TextConfig()
    override var config: TextConfig { _config }
    var selectedTextRange: Range<Int> {
        get {
            state.selectedTextRange
        }
        set {
            state.selectedTextRange = newValue
            textIsSelected = !selectedText.isEmpty

            updateSelectionState()
        }
    }

    func updateSelectionState() {
        if let n = focusedWidget as? TextNode {
            let isReference = (n is ProxyTextNode) && n.isDescendant(of: ReferencesSection.self)
            editor?.focusChanged(n.elementId, cursorPosition, selectedTextRange, isReference, NodeSelectionState(state.nodeSelection))
        }
    }

    var markedTextRange: Range<Int>? {
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
        }
    }

    func updateCursorPosition() {
        let n = focusedWidget as? TextNode
        if state.selectedTextRange.isEmpty {
            state.selectedTextRange = cursorPosition ..< cursorPosition
        }
        updateTextAttributesAtCursorPosition()
        n?.invalidateTextAsync()
        focusedWidget?.invalidate()
        editor?.reBlink()
        n?.updateCursor()
        if state.nodeSelection == nil {
            if needLayout {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(10))) { [weak self] in
                    guard let self = self,
                          let editor = self.editor
                    else { return }
                    editor.setHotSpotToCursorPosition()
                }
            } else {
                self.editor?.setHotSpotToCursorPosition()
            }
        }
        if let focused = focusedWidget as? ElementNode {
            focused.updateCursor()
        }
        if let n = n {
            let isReference = (n is ProxyTextNode) && n.isDescendant(of: ReferencesSection.self)
            editor?.focusChanged(n.elementId, cursorPosition, selectedTextRange, isReference, NodeSelectionState(state.nodeSelection))
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
        let text = node.text
        return text.substring(range: text.clamp(selectedTextRange))
    }

    override var root: TextRoot? {
        return self
    }

    var dailySummaryNode: TextNode?
    var continueToSummaryNode: TextNode?
    var topSpacerWidget: SpacerWidget?
    var middleSpacerWidget: SpacerWidget?
    var bottomSpacerWidget: SpacerWidget?
    var linksSection: LinksSection?
    var referencesSection: LinksSection?
    var debugSection: DebugSection?

    var otherSections: [Widget?] {
        [
            dailySummaryNode,
            continueToSummaryNode,
            topSpacerWidget,
            linksSection,
            middleSpacerWidget,
            referencesSection,
            bottomSpacerWidget,
            debugSection
        ]
    }

    override func buildTextChildren(elements: [BeamElement]) -> [Widget] {
        return super.buildTextChildren(elements: elements) + otherSections.compactMap { $0 }
    }

    weak var focusedWidget: Widget? {
        didSet {
            #if DEBUG
            assert(focusedWidget?.className != TextRoot.className())
            #endif
            guard oldValue !== focusedWidget else { return }
            let oldNode = oldValue as? TextNode
            let newNode = focusedWidget as? TextNode
            oldValue?.onUnfocus()
            oldNode?.invalidateTextAsync()
            oldValue?.invalidate()
            focusedWidget?.onFocus()
            newNode?.invalidateTextAsync()
            focusedWidget?.invalidate()
            cancelSelection(.current)
        }
    }

    weak var mouseHandler: Widget?

    override func onLayoutInvalidated() {
        editor?.invalidateLayout()
    }

    override var offsetInRoot: NSPoint { NSPoint() }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat) {
        super.init(editor: editor, element: element, nodeProvider: NodeProviderImpl(proxy: false), availableWidth: availableWidth)

        childInset = 0
        childrenSpacing = PreferencesManager.editorParentSpacing

        if let note = note {
            if note.isTodaysNote {
                createSummary()
            }
            topSpacerWidget = SpacerWidget(parent: self, spacerType: .beforeLinks, availableWidth: childAvailableWidth)
            linksSection = LinksSection(parent: self, note: note, availableWidth: childAvailableWidth)
            middleSpacerWidget = SpacerWidget(parent: self, spacerType: .beforeReferences, availableWidth: childAvailableWidth)
            referencesSection = ReferencesSection(parent: self, note: note, availableWidth: childAvailableWidth)
            bottomSpacerWidget = SpacerWidget(parent: self, spacerType: .bottom, availableWidth: childAvailableWidth)
            if PreferencesManager.showDebugSection {
                debugSection = DebugSection(parent: self, note: note, availableWidth: childAvailableWidth)

                if let isTodaysNote = self.note?.isTodaysNote, isTodaysNote {
                    var continueToNotes = [BeamNote]()
                    var continueToLink: Link?
                    if let continueToPageId = self.editor?.data?.clusteringManager.continueToPage {
                        continueToLink = LinkStore.linkFor(continueToPageId)
                    }

                    if let continueToNotesId = self.editor?.data?.clusteringManager.continueToNotes {
                        for noteId in continueToNotesId {
                            guard let note = BeamNote.fetch(id: noteId) else { continue }
                            continueToNotes.append(note)
                        }
                    }
                    debugSection?.setupContinueWidget(with: continueToNotes, and: continueToLink)
                }
            }
        }
        updateTextChildren(elements: element.children)

        self.selfVisible = false
        self.cursor = .arrow

        // Main bullets:
        if element.children.isEmpty {
            // Create one empty initial bullet
            element.addChild(BeamElement())
        }

        setPlaceholder()

        referencesSection?.open = false

        if !editor.journalMode {
            focus(widget: children.first ?? self, position: nil)
            focusedWidget = nodeFor(element.children.first ?? element, withParent: self)
            focusedWidget?.onFocus()
        }
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
        children.prefix(children.count).reduce("") { partial, node -> String in
            guard let node = node as? TextNode else { return partial }
            return partial + " " + node.fullStrippedText
        }
    }

    func focus(widget: Widget, position newPosition: Int? = 0) {
        guard widget !== self else { return }
        self.focusedWidget = widget
        if let position = newPosition {
            self.cursorPosition = position
        }
    }

    override func dumpWidgetTree(_ level: Int = 0) -> [String] {
        return [["=================================================="], super.dumpWidgetTree(level)].flatMap { $0 }
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
        guard let editor = self.editor else { return .zero }
        return NSRect(origin: CGPoint(), size: editor.frame.size)
    }

    struct ReferencingBreadCrumb {
        weak var breadCrumb: BreadCrumb?
        var note: BeamNote
    }

    private var breadCrumbs: [BeamNoteReference: ReferencingBreadCrumb] = [:]
    func getBreadCrumb(for noteReference: BeamNoteReference) -> BreadCrumb? {
        guard let breadCrumb = breadCrumbs[noteReference]?.breadCrumb else {
            guard let referencingNote = BeamNote.fetch(id: noteReference.noteID) else { return nil }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else { return nil }
            let breadCrumb = BreadCrumb(parent: self, sourceNote: referencingNote, element: referencingElement, availableWidth: childAvailableWidth)
            breadCrumbs[noteReference] = ReferencingBreadCrumb(breadCrumb: breadCrumb, note: referencingNote)
            return breadCrumb
        }
        return breadCrumb
    }

    override var isTreeBoundary: Bool { false }

    override var cmdManager: CommandManager<Widget> {
        guard let note = note else { fatalError("Trying to access the command manager on an unconnected TextRoot is a programming error.") }
        return note.cmdManager
    }

    var focusedCmdManager: CommandManager<Widget> {
        return focusedWidget?.cmdManager ?? cmdManager
    }

    func findLinkElement(_ id: UUID) -> ElementNode? {
        guard let links = linksSection else { return nil }
        return findLinkElement(id, in: links)
    }

    func findReferenceElement(_ id: UUID) -> ElementNode? {
        guard let references = referencesSection else { return nil }
        return findLinkElement(id, in: references)
    }

    private func findLinkElement(_ id: UUID, in widget: Widget) -> ElementNode? {
        if let breadcrumb = widget as? BreadCrumb,
           let node = breadcrumb.proxyNode,
           node.elementId == id {
            return node
        }
        for child in widget.children {
            if let e = findLinkElement(id, in: child) {
                return e
            }
        }
        return nil
    }

    func insertElementNearNonTextElement(_ string: String = "", after: ElementNode? = nil) {
        insertElementNearNonTextElement(BeamText(text: string), after: after)
    }

    func insertElementNearNonTextElement(_ string: BeamText, after: ElementNode? = nil) {
        guard let node = focusedWidget as? ElementNode else { return }
        node.cmdManager.beginGroup(with: "Insert Element")
        defer { node.cmdManager.endGroup() }
        let newElement = BeamElement(string)
        if node.element.children.isEmpty || caretIndex == 0 {
            let parent = node.parent as? ElementNode ?? node
            let previous = node.previousSibbling() as? ElementNode
            let afterElement = after ?? (caretIndex == 0 ? previous : node)
            node.cmdManager.insertElement(newElement, inElement: parent.unproxyElement, afterElement: afterElement?.unproxyElement)
        } else {
            let parent = node
            node.cmdManager.insertElement(newElement, inElement: parent.unproxyElement, afterElement: nil)
        }
        node.cmdManager.focus(newElement, in: node)
    }

    override func didMoveToWindow(_ window: NSWindow?) {
        super.didMoveToWindow(window)
        if window != nil, let note = note, note.isTodaysNote {
            self.setPlaceholder()
            self.updateSummary()
        }
    }

    // MARK: - Placeholder

    private func setPlaceholder() {
        guard let first = children.first as? TextNode,
              first.placeholder.isEmpty
        else { return }

        if let note = self.note, note.fastLinksAndReferences.isEmpty,
            note.isTodaysNote && element.children.count == 1 && element.children.first?.text.isEmpty ?? false {
            first.placeholder = BeamText(text: BeamPlaceholder.allPlaceholders.randomElement() ?? "Hello World!")
        }
    }

    // MARK: - Summary Engine

    private func createSummary() {
        if PreferencesManager.enableDailySummary {
            createDailyNode()
            createContinueToSummaryNode()
        }
    }

    private func createDailyNode() {
        if let dailySummaryElement = SummaryEngine.getDailySummary() {
            dailySummaryNode = TextNode(parent: self, element: dailySummaryElement, nodeProvider: nil, availableWidth: self.availableWidth)
        }
    }

    private func createContinueToSummaryNode() {
        if let continueToSummaryElement = SummaryEngine.getContinueToSummary() {
            continueToSummaryNode = TextNode(parent: self, element: continueToSummaryElement, nodeProvider: nil, availableWidth: self.availableWidth)
        }
    }

    func updateSummary() {
        guard PreferencesManager.enableDailySummary else { return }
        if dailySummaryNode != nil {
            updateDailySummary()
        } else {
            createDailyNode()
            updateTextChildren(elements: element.children)
        }
        if continueToSummaryNode != nil {
            updateContinueToSummary()
        } else {
            createContinueToSummaryNode()
            updateTextChildren(elements: element.children)
        }
    }

    private func updateDailySummary() {
        DispatchQueue.userInitiated.async {
            if let dailySummaryElement = SummaryEngine.getDailySummary() {
                DispatchQueue.mainSync {
                    if self.dailySummaryNode?.text.text != dailySummaryElement.text.text {
                        self.dailySummaryNode?.element = dailySummaryElement
                    }
                }
            }
        }
    }

    private func updateContinueToSummary() {
        DispatchQueue.userInitiated.async {
            if let continueToSummaryElement = SummaryEngine.getContinueToSummary() {
                DispatchQueue.mainSync {
                    if self.continueToSummaryNode?.text.text != continueToSummaryElement.text.text {
                        self.continueToSummaryNode?.element = continueToSummaryElement
                    }
                }
            }
        }
    }
}
