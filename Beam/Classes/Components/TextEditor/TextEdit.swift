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

public struct MouseInfo {
    var position: NSPoint
    var event: NSEvent

    init(_ node: Widget, _ position: NSPoint, _ event: NSEvent) {
        self.position = NSPoint(x: position.x - node.frameInDocument.minX, y: position.y - node.frameInDocument.minY)
        self.event = event
    }
}

// swiftlint:disable:next type_body_length
public class BeamTextEdit: NSView, NSTextInputClient, CALayerDelegate {
    var data: BeamData?
    var note: BeamElement! {
        didSet {
            updateRoot(with: note)
        }
    }

    func updateRoot(with note: BeamElement) {
        guard note != rootNode?.element else { return }
        if let layers = layer?.sublayers {
            for l in layers where l !== titleLayer {
                l.removeFromSuperlayer()
            }
        }

//        guard mapping[note] == nil else { return }
        guard let rootnode = nodeFor(note) as? TextRoot else { fatalError() }
        rootNode = rootnode
        accessingMapping = true
        mapping[note] = rootNode
        accessingMapping = false
        purgeDeadNodes()

        node = {
            guard let n = note.children.first else { return nodeFor(note) }
            return nodeFor(n)
        }()

        // Remove all subsciptions:
        noteCancellables = []

        // Subscribe to the note's changes
        note.$changed
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [unowned self] _ in
                guard let note = note as? BeamNote else { return }
                note.detectLinkedNotes(documentManager)
                note.save(documentManager: self.documentManager)
            }.store(in: &noteCancellables)
    }

    private var noteCancellables = [AnyCancellable]()
    internal var cursorStartPosition = 0
    internal var popover: BidirectionalPopover?

    public init(root: BeamElement, font: Font = Font.main) {
        BeamNote.detectLinks(documentManager)

        self.config.font = font
        note = root
        super.init(frame: NSRect())
        let l = CALayer()
        self.layer = l
        l.backgroundColor = NSColor.editorBackgroundColor.cgColor
        l.addSublayer(titleLayer)
        //titleLayer.backgroundColor = NSColor.red.cgColor.copy(alpha: 0.2)
        titleLayer.backgroundColor = NSColor(white: 1, alpha: 0).cgColor
        titleLayer.setNeedsDisplay()

        layer?.delegate = self
        titleLayer.delegate = self
//        self.wantsLayer = true

        timer = Timer.init(timeInterval: 1.0 / 60.0, repeats: true) { [unowned self] _ in
            let now = CFAbsoluteTimeGetCurrent()
            if self.blinkTime < now && self.hasFocus {
                self.blinkPhase.toggle()
                self.blinkTime = now + (self.blinkPhase ? self.onBlinkTime : self.offBlinkTime)
                node.invalidate()
            }

            // Prepare animation frame:
            var t = tick
            t.previous = tick.now
            t.now = CACurrentMediaTime()
            t.delta = t.now - t.previous
            t.fdelta = Float(t.delta)
            t.index += 1
            tick = t
        }
        RunLoop.main.add(timer, forMode: .default)

        _inputContext = NSTextInputContext(client: self)

        initBlinking()
        updateRoot(with: root)
    }

    deinit {
        timer.invalidate()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var timer: Timer!
    @Published var tick = Tick()

    var minimumWidth: CGFloat = 300 {
        didSet {
            if oldValue != minimumWidth {
                invalidateIntrinsicContentSize()
            }
        }
    }
    var maximumWidth: CGFloat = 1024 {
        didSet {
            if oldValue != minimumWidth {
                invalidateIntrinsicContentSize()
            }
        }
    }

    var leadingAlignment = CGFloat(160) {
        didSet {
            if oldValue != minimumWidth {
                invalidateIntrinsicContentSize()
            }
        }
    }
    var traillingPadding = CGFloat(80) {
        didSet {
            if oldValue != minimumWidth {
                invalidateIntrinsicContentSize()
            }
        }
    }

    var showTitle = true {
        didSet {
            titleLayer.isHidden = !showTitle
        }
    }
    var titleLayer = CALayer()

    public var activated: () -> Void = { }
    public var activateOnLostFocus = true
    public var useFocusRing = false
    public var openURL: (URL) -> Void = { _ in }
    public var openCard: (String) -> Void = { _ in }
    public var onStartEditing: () -> Void = { }
    public var onEndEditing: () -> Void = { }
    public var onStartQuery: (TextNode) -> Void = { _ in }

    public var config = TextConfig()

    public override var undoManager: UndoManager { rootNode.undoManager }

    var selectedTextRange: Range<Int> {
        set {
            assert(newValue.lowerBound != NSNotFound)
            assert(newValue.upperBound != NSNotFound)
            rootNode.state.selectedTextRange = newValue
            reBlink()
        }
        get {
            rootNode.state.selectedTextRange
        }
    }
    var markedTextRange: Range<Int> {
        set {
            assert(newValue.lowerBound != NSNotFound)
            assert(newValue.upperBound != NSNotFound)
            rootNode.state.markedTextRange = newValue
            reBlink()
        }
        get {
            rootNode.state.markedTextRange
        }

    }

    var selectedText: String {
        return rootNode.selectedText
    }

    static let bigThreshold = CGFloat(866)
    var isBig: Bool {
        frame.width >= Self.bigThreshold
    }

    public override var frame: NSRect {
        didSet {
//            print("editor[\(rootNode.note.title)] frame changed to \(frame)")
            let oldbig = oldValue.width >= Self.bigThreshold
            let newbig = isBig

            if oldbig != newbig {
                rootNode.deepInvalidateText()
                invalidateLayout()
            }

            relayoutRoot()
        }
    }

    func relayoutRoot() {
//        print("editor[\(rootNode.note.title)] relayout root to \(frame)")
        let r = bounds
        let width = CGFloat(isBig ? frame.width - 200 - leadingAlignment : 450)
        let rect = NSRect(x: leadingAlignment, y: topOffsetActual, width: width, height: r.height)
        //print("relayoutRoot -> \(rect)")
        rootNode.availableWidth = rect.width
        rootNode.setLayout(rect)
    }

    // This is the root node of what we are editing:
    var rootNode: TextRoot!

    // This is the node that the user is currently editing. It can be any node in the rootNode tree
    var node: Widget {
        set {
            invalidate(rootNode.node.textFrameInDocument)
            rootNode.node = newValue
            invalidate(rootNode.node.textFrameInDocument)
        }
        get {
            rootNode.node
        }
    }

    var topOffset: CGFloat = 28 { didSet { invalidateIntrinsicContentSize() } }
    var footerHeight: CGFloat = 60 { didSet { invalidateIntrinsicContentSize() } }
    var topOffsetActual: CGFloat {
        config.keepCursorMidScreen ? visibleRect.height / 2 : topOffset
    }

    override public var intrinsicContentSize: NSSize {
        return NSSize(width: 300, height: rootNode.idealSize.height + topOffsetActual + footerHeight)
    }

    public func setHotSpot(_ spot: NSRect) {
        _ = scrollToVisible(spot)
    }

    public func invalidateLayout() {
        invalidateIntrinsicContentSize()
        needsLayout = true
        invalidate()
    }

    public override func layout() {
//        print("editor[\(rootNode.note.title)] layout \(frame)")
        relayoutRoot()
        super.layout()
        if scrollToCursorAtLayout {
            scrollToCursorAtLayout = false
            setHotSpotToCursorPosition()
        }
    }

    public func invalidate(_ rect: NSRect? = nil) {
        guard let r = rect else { setNeedsDisplay(bounds); return }
        setNeedsDisplay(r)
    }

    // Text Input from AppKit:
    private var _inputContext: NSTextInputContext!
    public override var inputContext: NSTextInputContext? {
        return _inputContext
    }

    public func hasMarkedText() -> Bool {
        return rootNode.hasMarkedText()
    }

    public func setMarkedText(string: String, selectedRange: Range<Int>, replacementRange: Range<Int>) {
        rootNode.setMarkedText(string: string, selectedRange: selectedRange, replacementRange: replacementRange)
        reBlink()
    }

    public func unmarkText() {
        markedTextRange = 0..<0
    }

    public func insertText(string: String, replacementRange: Range<Int>) {
        guard let node = node as? TextNode else { return }
        guard !node.readOnly else { return }
        defer { lastInput = string }
        guard preDetectInput(string) else { return }
        rootNode.insertText(string: string, replacementRange: replacementRange)
        updatePopover()
        postDetectInput(string)
        reBlink()
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        return rootNode.firstRect(forCharacterRange: range)
    }

    public var enabled = true

    @Published var hasFocus = false

    public override func becomeFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = true
        invalidate()
        onStartEditing()
        return super.becomeFirstResponder()
    }

    public override func resignFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = false
        rootNode.cancelSelection()
        (node as? TextNode)?.invalidateText() // force removing the syntax highlighting
        node.invalidate()
        if activateOnLostFocus {
            activated()
        }
        onEndEditing()
        return super.resignFirstResponder()
    }

    func pressEnter(_ option: Bool, _ command: Bool) {
        guard let node = node as? TextNode else { return }
        guard !node.readOnly else { return }

        if popover != nil {
            popover?.doCommand(.insertNewline)
            return
        }

        if option {
            rootNode.doCommand(.insertNewline)
        } else if command {
            onStartQuery(node)
        } else {
            if node.text.isEmpty && node.isEmpty && node.parent !== rootNode {
                rootNode.decreaseIndentation()
                return
            }
            rootNode.eraseSelection()
            let splitText = node.text.extract(range: rootNode.cursorPosition ..< node.text.count)
            node.text.removeLast(node.text.count - rootNode.cursorPosition)
            let element = BeamElement()
            element.text = splitText
            let newNode = nodeFor(element)
            let elements = node.element.children
            for c in elements {
                newNode.element.addChild(c)
            }

            _ = node.parent?.insert(node: newNode, after: node)
            rootNode.cursorPosition = 0

            scrollToCursorAtLayout = true
            self.node = newNode
        }
    }

    //swiftlint:disable cyclomatic_complexity function_body_length
    override open func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        let control = event.modifierFlags.contains(.control)
        let command = event.modifierFlags.contains(.command)

        if self.hasFocus {
            if let k = event.specialKey {
                switch k {
                case .enter:
                    pressEnter(option, command)
                case .carriageReturn:
                    pressEnter(option, command)
                    return
                case .leftArrow:
                    if control && option && command {
                        guard let node = node as? TextNode else { return }
                        node.fold()
                    } else if shift {
                        if option {
                            rootNode.doCommand(.moveWordLeftAndModifySelection)
                        } else if command {
                            rootNode.doCommand(.moveToBeginningOfLineAndModifySelection)
                        } else {
                            rootNode.doCommand(.moveLeftAndModifySelection)
                        }
                        return
                    } else if command && popover != nil {
                        rootNode.doCommand(.moveToBeginningOfLine)
                        dismissPopover()
                    } else {
                        if option {
                            rootNode.doCommand(.moveWordLeft)
                        } else if command {
                            rootNode.doCommand(.moveToBeginningOfLine)
                        } else {
                            updatePopover(.moveLeft)
                            rootNode.doCommand(.moveLeft)
                        }
                        return
                    }
                case .rightArrow:
                    if control && option && command {
                        guard let node = node as? TextNode else { return }
                        node.unfold()
                    } else if shift {
                        if option {
                            rootNode.doCommand(.moveWordRightAndModifySelection)
                        } else if command {
                            rootNode.doCommand(.moveToEndOfLineAndModifySelection)
                        } else {
                            rootNode.doCommand(.moveRightAndModifySelection)
                        }
                        return
                    } else {
                        if option {
                            rootNode.doCommand(.moveWordRight)
                        } else if command {
                            rootNode.doCommand(.moveToEndOfLine)
                        } else {
                            rootNode.doCommand(.moveRight)
                        }
                        return
                    }
                case .upArrow:
                    if shift {
                        rootNode.doCommand(.moveUpAndModifySelection)
                        return
                    } else if let popover = popover {
                        popover.doCommand(.moveUp)
                        return
                    } else {
                        rootNode.doCommand(.moveUp)
                        return
                    }
                case .downArrow:
                    if shift {
                        rootNode.doCommand(.moveDownAndModifySelection)
                        return
                    } else if let popover = popover {
                        popover.doCommand(.moveDown)
                        return
                    } else {
                        rootNode.doCommand(.moveDown)
                        return
                    }
                case .delete:
                    rootNode.doCommand(.deleteBackward)
                    updatePopover(.deleteForward)
                    return

                case .backTab:
                    rootNode.doCommand(.decreaseIndentation)
                    return

                case .tab:
                    rootNode.doCommand(.increaseIndentation)
                    return

                default:
                    print("Special Key \(k)")
                }
            }

            switch event.keyCode {
            case 117: // delete
                rootNode.doCommand(.deleteForward)
                return
            case 53: // escape
                if popover != nil { dismissPopover() }
                rootNode.cancelSelection()
                return
            default:
                break
            }

            if let ch = event.charactersIgnoringModifiers {
                switch ch {
                case "a":
                    if command {
                        if popover != nil { dismissPopover() }
                        rootNode.doCommand(.selectAll)
                        return
                    }
                case "[":
                    if command {
                        rootNode.doCommand(.decreaseIndentation)
                        return
                    }
                case "]":
                    if command {
                        rootNode.doCommand(.increaseIndentation)
                        return
                    }

                default:
                    break
                }
            }

        }
        inputContext?.handleEvent(event)
        //super.keyDown(with: event)
    }
    //swiftlint:enable cyclomatic_complexity function_body_length

    func nodeAt(point: CGPoint) -> Widget? {
        let p = NSPoint(x: point.x - rootNode.frame.origin.x, y: point.y - rootNode.frame.origin.y)
        return rootNode.nodeAt(point: p)
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
        guard let node = node as? TextNode else { return nil }
        let str = node.attributedString.attributedSubstring(from: range)
        Logger.shared.logDebug("TextInput.attributedString(range: \(range), actualRange: \(String(describing: actualRange))) -> \(str)", category: .document)
        return str
    }

    public func attributedString() -> NSAttributedString {
        guard let node = node as? TextNode else { return "".attributed }
        return node.attributedString
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
        rootNode.eraseSelection()
    }

    @IBAction func undo(_ sender: Any) {
        undoManager.undo()
    }

    @IBAction func redo(_ sender: Any) {
        undoManager.redo()
    }

    var inputDetectorState: Int = 0
    var inputDetectorEnabled: Bool { inputDetectorState >= 0 }

    func disableInputDetector() {
        inputDetectorState -= 1
    }

    func enableInputDetector() {
        inputDetectorState -= 1
    }

    var lastInput: String = ""

    // swiftlint:disable:next function_body_length
    func preDetectInput(_ input: String) -> Bool {
        guard inputDetectorEnabled else { return true }
        guard let node = node as? TextNode else { return true }
        defer { lastInput = input }

        let insertPair = { [unowned self] (left: String, right: String) in
            node.text.insert(right, at: selectedTextRange.upperBound)
            node.text.insert(left, at: selectedTextRange.lowerBound)
            rootNode.cursorPosition += 1
            selectedTextRange = selectedTextRange.lowerBound + 1 ..< selectedTextRange.upperBound + 1
        }

        let handlers: [String: () -> Bool] = [
            "@": { [unowned self] in
                self.showBidirectionalPopover()
                return true
             },
             "#": { [unowned self] in
                self.showBidirectionalPopover()
                return true
             },
            "[[": { [unowned self] in
                insertPair("[", "]")
                Logger.shared.logInfo("Transform selection into internal link", category: .ui)
                if !self.selectedTextRange.isEmpty {
                    node.text.makeInternalLink(self.selectedTextRange)
                    return false
                } else {
                    self.showBidirectionalPopover()
                }

                return true
            },
            "[": {
                insertPair("[", "]")
                return false
            },
            "(": {
                insertPair("(", ")")
                return false
            },
            "{": {
                insertPair("{", "}")
                return false
            },
            "\"": {
                insertPair("\"", "\"")
                return false
            }
        ]

        if let handler = handlers[lastInput + input] {
            return handler()
        } else if let handler = handlers[input] {
            return handler()
        }

        return true
    }

    // swiftlint:disable:next cyclomatic_complexity
    func postDetectInput(_ input: String) {
        guard inputDetectorEnabled else { return }
        guard let node = node as? TextNode else { return }

        let makeQuote = { [unowned self] in
            let level1 = node.text.prefix(2).text == "> "
            let level2 = node.text.prefix(3).text == ">> "
            let level = level1 ? 1 : (level2 ? 2 : 0)
            if node.cursorPosition <= 3, level > 0 {
                Logger.shared.logInfo("Make quote", category: .ui)

                node.text.removeAttributes([.quote(0, "", "")], from: node.text.wholeRange)
                node.text.addAttributes([.quote(level, "", "")], to: node.text.wholeRange)
                node.text.removeFirst(level + 1)
                self.rootNode.cursorPosition = 0
            }
        }

        let makeHeader = { [unowned self] in
            let level1 = node.text.prefix(2).text == "# "
            let level2 = node.text.prefix(3).text == "## "
            let level = level1 ? 1 : (level2 ? 2 : 0)
            if node.cursorPosition <= 3, level != 0 {
                Logger.shared.logInfo("Make header", category: .ui)

                // In this case we will reparent all following sibblings that are not a header to the current node as Paper does
                guard self.node.isEmpty else { return }
                guard let parent = self.node.parent else { return }
                guard let index = self.node.indexInParent else { return }
                for sibbling in parent.children.suffix(from: index + 1) {
                    guard let sibbling = sibbling as? TextNode else { return }
                    guard !sibbling.isHeader else { return }
                    self.node.addChild(sibbling)
                }

                node.text.removeAttributes([.heading(0)], from: node.text.wholeRange)
                node.text.addAttributes([.heading(level)], to: node.text.wholeRange)
                node.text.removeFirst(level + 1)
                self.rootNode.cursorPosition = 0
            }
        }

        let handlers: [String: () -> Void] = [
            "#": makeHeader,
            ">": makeQuote,
            " ": { //[unowned self] in
                makeHeader()
                makeQuote()
            }
        ]

        if let handler = handlers[input] {
            handler()
        } else if let handler = handlers[lastInput + input] {
            handler()
        }
    }

    @IBAction func paste(_ sender: Any) {
        if let s = NSPasteboard.general.string(forType: .string) {
            disableInputDetector()
            insertText(string: s, replacementRange: selectedTextRange)
            enableInputDetector()
        }
    }

    func initBlinking() {
        let defaults = UserDefaults.standard
        let von = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOn")
        onBlinkTime = von == 0 ? onBlinkTime : von * 1000
        let voff = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOff")
        offBlinkTime = voff == 0 ? offBlinkTime : voff * 1000
    }

    var _title: TextFrame?
    var title: TextFrame {
        if let t = _title {
            return t
        }

        guard let titleString = rootNode.note?.title.attributed else { fatalError() }
        let f = NSFont.systemFont(ofSize: isBig ? 13 : 11, weight: .semibold)
        titleString.addAttribute(.font, value: f, range: titleString.wholeRange)
        titleString.addAttribute(.foregroundColor, value: NSColor.editorControlColor, range: titleString.wholeRange)
        _title = Font.draw(string: titleString, atPosition: NSPoint(x: 0, y: 0), textWidth: frame.width)
        return _title!
    }

    func reBlink() {
        blinkPhase = true
        blinkTime = CFAbsoluteTimeGetCurrent() + onBlinkTime
        node.invalidate()
    }

    public func positionAt(point: NSPoint) -> Int {
        guard let node = node as? TextNode else { return 0 }
        let fid = node.frameInDocument
        return node.positionAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    override public func mouseDown(with event: NSEvent) {
        //       window?.makeFirstResponder(self)
        reBlink()
        let point = convert(event.locationInWindow)
        guard let newNode = rootNode.dispatchMouseDown(mouseInfo: MouseInfo(rootNode, point, event)) else {
            guard let n = rootNode.children.first else { return }
            rootNode.cursorPosition = 0
            node = n
            return
        }

        node = newNode
    }

    var scrollToCursorAtLayout = false
    public func setHotSpotToCursorPosition() {
        setHotSpot(rectAt(rootNode.cursorPosition).insetBy(dx: -30, dy: -30))
    }

    public func rectAt(_ position: Int) -> NSRect {
        guard let node = node as? TextNode else { return NSRect() }
        let origin = node.offsetInDocument
        return node.rectAt(position).offsetBy(dx: origin.x, dy: origin.y)
    }

    var firstDrag = true
    var ignoreFirstDrag = false

    override public func mouseDragged(with event: NSEvent) {
        guard !(firstDrag && ignoreFirstDrag) else {
            firstDrag = false
            return
        }

        //        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow)
        _ = rootNode.dispatchMouseDragged(mouseInfo: MouseInfo(rootNode, point, event))
    }

    var hoveredNode: TextNode? {
        didSet {
            if let old = oldValue {
                if old !== hoveredNode {
                    old.hover = false
                }
            }

            if let new = hoveredNode {
                new.hover = true
            }
        }
    }

    func convert(_ point: NSPoint) -> NSPoint {
        return self.convert(point, from: nil)
    }

    override public func mouseMoved(with event: NSEvent) {
        if !(window?.contentView?.frame.contains(event.locationInWindow) ?? false) {
            super.mouseMoved(with: event)
            return
        }
        let point = convert(event.locationInWindow)
        let newNode = nodeAt(point: point) as? TextNode
        if newNode !== hoveredNode {
            hoveredNode = newNode
        }

        _ = node.mouseMoved(mouseInfo: MouseInfo(node, point, event))
        _ = hoveredNode?.mouseMoved(mouseInfo: MouseInfo(hoveredNode!, point, event))
    }

    override public func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow)
        if nil != rootNode.dispatchMouseUp(mouseInfo: MouseInfo(rootNode, point, event)) {
            return
        }
        super.mouseUp(with: event)
    }

    public override var acceptsFirstResponder: Bool { true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        guard let window = newWindow else { return }
        window.acceptsMouseMovedEvents = true
        for elem in mapping {
            elem.value.layer.contentsScale = window.backingScaleFactor
            elem.value.contentsScale = window.backingScaleFactor
            elem.value.invalidate()
        }
        titleLayer.contentsScale = window.backingScaleFactor
    }

    var onBlinkTime: Double = 0.7
    var offBlinkTime: Double = 0.5
    var blinkTime: Double = CFAbsoluteTimeGetCurrent()
    var blinkPhase = true

    public override var isFlipped: Bool { true }

    // CALayerDelegate
    let titlePadding = CGFloat(20)
    public func layoutSublayers(of layer: CALayer) {
        guard layer === self.layer else { return }
        let h = title.frame.height
        titleLayer.bounds = CGRect(x: 0, y: 0, width: leadingAlignment, height: h + 15)
//        let x = leadingAlignment - title.frame.width - titlePadding
        let y = topOffset
        titleLayer.anchorPoint = NSPoint()
        titleLayer.position = NSPoint(x: 0, y: y)
//        print("titleFrame: \(titleLayer.bounds) / \(titleLayer.position) (hidden: \(titleLayer.isHidden))")

        relayoutRoot()
    }

    public func draw(_ layer: CALayer, in context: CGContext) {
        guard layer === self.titleLayer else { return }

//        print("draw title into titleLayer: \(titleLayer.bounds) / \(titleLayer.position) (hidden: \(titleLayer.isHidden))")
        context.saveGState()
        context.textMatrix = CGAffineTransform.identity
        let x = leadingAlignment - title.frame.width - titlePadding
        let n = rootNode.children.first as? TextNode
        let y = n?.firstLineBaseline ?? 0
        context.translateBy(x: x, y: y)
        title.draw(context)
        context.restoreGState()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = NSColor.editorBackgroundColor.cgColor

        layer?.setNeedsDisplay()
        titleLayer.setNeedsDisplay()
        rootNode.deepInvalidateRendering()
        rootNode.deepInvalidateText()
    }

    let documentManager = DocumentManager(coreDataManager: CoreDataManager.shared)

    @IBAction func saveDocument(_ sender: Any?) {
        print("Save document!")
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = .prettyPrinted
//        do {
//            let data = try encoder.encode(rootNode)
//            let string = String(data: data, encoding: .utf8)!
//            print("JSon document:\n\(string)")
//        } catch {
//            print("Encoding error")
//        }
        rootNode.note?.save(documentManager: documentManager)
        BeamNote.detectLinks(documentManager)
    }

    func nodeFor(_ element: BeamElement) -> TextNode {
        if let node = mapping[element] {
            return node
        }

        let node: TextNode = {
            guard let note = element as? BeamNote else {
                guard element.note == nil || element.note == self.note else {
                    return LinkedReferenceNode(editor: self, element: element)
                }
                return TextNode(editor: self, element: element)
            }
            return TextRoot(editor: self, element: note)
        }()

        accessingMapping = true
        mapping[element] = node
        accessingMapping = false
        purgeDeadNodes()

        if let w = window {
            node.contentsScale = w.backingScaleFactor
        }
        layer?.addSublayer(node.layer)

        return node
    }

    private var accessingMapping = false
    private var mapping: [BeamElement: TextNode] = [:]
    private var deadNodes: [TextNode] = []

    private func showBidirectionalPopover() {
        guard popover == nil else { return }
        cursorStartPosition = rootNode.cursorPosition
        initPopover()
    }

    func purgeDeadNodes() {
        guard !accessingMapping else { return }
        for dead in deadNodes {
            removeNode(dead)
        }
        deadNodes.removeAll()
    }

    func removeNode(_ node: TextNode) {
        guard !accessingMapping else {
            deadNodes.append(node)
            return
        }
        mapping.removeValue(forKey: node.element)
    }
}
