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

    init(_ node: TextNode, _ position: NSPoint, _ event: NSEvent) {
        self.position = NSPoint(x: position.x - node.frameInDocument.minX, y: position.y - node.frameInDocument.minY)
        self.event = event
    }
}

public struct BTextEdit: NSViewRepresentable {
    var note: Note
    var openURL: (URL) -> Void
    var openCard: (String) -> Void
    var onStartEditing: () -> Void = { }
    var onEndEditing: () -> Void = { }
    var minimumWidth: CGFloat = 800
    var maximumWidth: CGFloat = 1024

    var leadingAlignment = CGFloat(160)
    var traillingPadding = CGFloat(80)

    public func makeNSView(context: Context) -> BeamTextEdit {
        let root = TextRoot(CoreDataManager.shared, note: note)
        let nsView = BeamTextEdit(root: root, font: Font.main)
        nsView.openURL = openURL
        nsView.openCard = openCard
        nsView.onStartEditing = onStartEditing
        nsView.onEndEditing = onEndEditing
        return nsView
    }

    public func updateNSView(_ nsView: BeamTextEdit, context: Context) {
        print("display note: \(note)")
        if nsView.rootNode.note !== note {
            nsView.rootNode = TextRoot(CoreDataManager.shared, note: note)
            if let note = nsView.rootNode.children.first {
                nsView.node = note
            }
        }
        nsView.openURL = openURL
        nsView.openCard = openCard
        nsView.onStartEditing = onStartEditing
        nsView.onEndEditing = onEndEditing

        nsView.minimumWidth = minimumWidth
        nsView.maximumWidth = maximumWidth

        nsView.leadingAlignment = leadingAlignment
        nsView.traillingPadding = traillingPadding

    }

    public typealias NSViewType = BeamTextEdit
}

// swiftlint:disable type_body_length
public class BeamTextEdit: NSView, NSTextInputClient {
    public init(root: TextRoot, font: Font = Font.main) {
        self.config.font = font
        rootNode = root
        super.init(frame: NSRect())

        root._editor = self
        timer = Timer.init(timeInterval: 1.0 / 60.0, repeats: true) { [unowned self] _ in
            let now = CFAbsoluteTimeGetCurrent()
            if self.blinkTime < now && self.hasFocus {
                self.blinkPhase.toggle()
                self.blinkTime = now + (self.blinkPhase ? self.onBlinkTime : self.offBlinkTime)
                self.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        _inputContext = NSTextInputContext(client: self)

        initBlinking()
    }

    deinit {
        timer.invalidate()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var timer: Timer!

    var minimumWidth: CGFloat = 800 {
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

    public var activated: () -> Void = { }
    public var activateOnLostFocus = true
    public var useFocusRing = false
    public var openURL: (URL) -> Void = { _ in }
    public var openCard: (String) -> Void = { _ in }
    public var onStartEditing: () -> Void = { }
    public var onEndEditing: () -> Void = { }

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
    var cursorPosition: Int {
        set {
            assert(newValue != NSNotFound)
            rootNode.state.cursorPosition = newValue
            reBlink()
            setHotSpotToCursorPosition()
            if config.contextualSyntax {
                node.invalidateTextRendering()
            }
        }

        get {
            rootNode.state.cursorPosition
        }
    }

    var selectedText: String {
        return rootNode.selectedText
    }

    public override var frame: NSRect {
        didSet {
//            print("editor[\(rootNode.note.title)] frame changed to \(frame)")
            relayoutRoot()
        }
    }

    func relayoutRoot() {
//        print("editor[\(rootNode.note.title)] relayout root to \(frame)")
        let r = bounds
        let width = min(max(minimumWidth, r.width - (leadingAlignment + traillingPadding)), maximumWidth)
        let rect = NSRect(x: leadingAlignment, y: topOffset, width: width, height: r.height)
        //print("relayoutRoot -> \(rect)")
        rootNode.setLayout(rect)
    }

    // This is the root node of what we are editing:
    var rootNode: TextRoot {
        didSet {
            guard oldValue !== rootNode else { return }
            rootNode._editor = self
            if let firstNode = rootNode.children.first {
                node = firstNode
            } else {
                guard let newBullet = rootNode.note?.createBullet(CoreDataManager.shared.mainContext, content: "", afterBullet: nil) else { return }
                let newNode = TextNode(bullet: newBullet, recurse: false)
                var children = rootNode.children
                children.append(newNode)
                cursorPosition = 0
                node = newNode
            }
            // put a fake layout as an init
            rootNode.setLayout(NSRect(x: 0, y: 0, width: max(minimumWidth, frame.width), height: max(100, frame.height)))

            // and invalidate the layout so that everything is recalculated again
            invalidateLayout()
            invalidate()
        }
    }

    // This is the node that the user is currently editing. It can be any node in the rootNode tree
    var node: TextNode {
        set {
            rootNode.node = newValue
            invalidate()
        }
        get {
            rootNode.node
        }
    }

    var topOffset: CGFloat {
        config.keepCursorMidScreen ? visibleRect.height / 2 : 0
    }

    override public var intrinsicContentSize: NSSize {
        let s = NSSize(width: minimumWidth + leadingAlignment + traillingPadding, height: rootNode.idealSize.height + topOffset)
//        print("editor[\(rootNode.note.title)] new intrinsic content size \(s)")
        return s
    }

    public func setHotSpot(_ spot: NSRect) {
        if let sv = superview as? NSScrollView {
            sv.scrollToVisible(spot)
        }
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
        rootNode.insertText(string: string, replacementRange: replacementRange)
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
        rootNode.cancelSelection()
        invalidate()
        node.invalidateTextRendering() // force removing the syntax highlighting
        if activateOnLostFocus {
            activated()
        }
        hasFocus = false
        onEndEditing()
        return super.resignFirstResponder()
    }

    func pressEnter(_ option: Bool) {
        if option {
            rootNode.doCommand(.insertNewline)
        } else {
            node.text.removeSubrange(node.text.range(from: selectedTextRange))
            cursorPosition = selectedTextRange.startIndex
            let splitText = node.text.substring(from: cursorPosition, to: node.text.count)
            node.text.removeLast(node.text.count - cursorPosition)
            guard let newBullet = node.bullet?.note?.createBullet(CoreDataManager.shared.mainContext, content: splitText, afterBullet: node.bullet) else { return }
            let newNode = TextNode(bullet: newBullet, recurse: false)
            let nodes = node.children
            for c in nodes {
                newNode.addChild(c)
                if let b = c.bullet {
                    newNode.bullet?.addToChildren(b)
                }
            }

            _ = node.parent?.insert(node: newNode, after: node)
            cursorPosition = 0
            node = newNode
            rootNode.cancelSelection()
        }
    }

    //swiftlint:disable cyclomatic_complexity function_body_length
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
                            rootNode.doCommand(.moveWordLeftAndModifySelection)
                        } else if command {
                            rootNode.doCommand(.moveToBeginningOfLineAndModifySelection)
                        } else {
                            rootNode.doCommand(.moveLeftAndModifySelection)
                        }
                        return
                    } else {
                        if option {
                            rootNode.doCommand(.moveWordLeft)
                        } else if command {
                            rootNode.doCommand(.moveToBeginningOfLine)
                        } else {
                            rootNode.doCommand(.moveLeft)
                        }
                        return
                    }
                case .rightArrow:
                    if shift {
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
                    } else {
                        rootNode.doCommand(.moveUp)
                        return
                    }
                case .downArrow:
                    if shift {
                        rootNode.doCommand(.moveDownAndModifySelection)
                        return
                    } else {
                        rootNode.doCommand(.moveDown)
                        return
                    }
                case .delete:
                    rootNode.doCommand(.deleteBackward)
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
                rootNode.cancelSelection()
                return
            default:
                break
            }

            if let ch = event.charactersIgnoringModifiers {
                switch ch {
                case "a":
                    if command {
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
                default: break
                }
            }

        }
        inputContext?.handleEvent(event)
        //super.keyDown(with: event)
    }
    //swiftlint:enable cyclomatic_complexity function_body_length

    func nodeAt(point: CGPoint) -> TextNode? {
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
        rootNode.eraseSelection()
    }

    @IBAction func undo(_ sender: Any) {
        undoManager.undo()
    }

    @IBAction func redo(_ sender: Any) {
        undoManager.redo()
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
    }

    public func draw(in context: CGContext) {
//        print("\n\ndraw visibleRect: \(visibleRect)")
        // Draw the background
        context.setFillColor(NSColor(named: "EditorBackgroundColor")!.cgColor)
        context.addRect(bounds)
        context.drawPath(using: .eoFill)

        context.saveGState(); defer { context.restoreGState() }
        context.translateBy(x: rootNode.frame.origin.x, y: rootNode.frame.origin.y)
//        var vis = visibleRect
//        vis.origin.x -= rootNode.frame.origin.x
//        vis.origin.y -= rootNode.frame.origin.y
        let vis = bounds
        rootNode.draw(in: context, visibleRect: vis)
    }

    public override func draw(_ dirtyRect: NSRect) {
//        print("\n\n\n\ndraw dirtyRect: \(dirtyRect)")
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

    public func lineAt(point: NSPoint) -> Int {
        let fid = node.frameInDocument
        return node.lineAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    public func positionAt(point: NSPoint) -> Int {
        let fid = node.frameInDocument
        return node.positionAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    public func linkAt(point: NSPoint) -> URL? {
        let fid = node.frameInDocument
        return node.linkAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    public func internalLinkAt(point: NSPoint) -> String? {
        let fid = node.frameInDocument
        return node.internalLinkAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    override public func mouseDown(with event: NSEvent) {
        //       window?.makeFirstResponder(self)
        if event.clickCount == 1 {
            reBlink()
            let point = convert(event.locationInWindow)
            guard let newNode = nodeAt(point: point) else { return }
            if newNode.mouseDown(mouseInfo: MouseInfo(newNode, point, event)) {
                return
            }

            if newNode !== node && !newNode.readOnly {
                node = newNode
            }

            if let link = linkAt(point: point) {
                openURL(link)
                return
            }
            if let link = internalLinkAt(point: point) {
                openCard(link)
                return
            }
            cursorPosition = positionAt(point: point)
            rootNode.cancelSelection()
            dragMode = .select(cursorPosition)

        } else {
            rootNode.doCommand(.selectAll)
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
        let point = convert(event.locationInWindow)

        if node.mouseDragged(mouseInfo: MouseInfo(node, point, event)) {
            return
        }

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
        guard let newNode = nodeAt(point: point) else { return }
        if newNode !== hoveredNode {
            hoveredNode = newNode
        }

        _ = node.mouseMoved(mouseInfo: MouseInfo(node, point, event))
        _ = hoveredNode?.mouseMoved(mouseInfo: MouseInfo(hoveredNode!, point, event))

        invalidate()
    }

    override public func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow)
        dragMode = .none
        if node.mouseUp(mouseInfo: MouseInfo(node, point, event)) {
            return
        }
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

    public override var isFlipped: Bool { true }

    public override func viewDidMoveToWindow() {
        setupNotificationListeners()
    }

    func setupNotificationListeners() {
        let nc = NotificationCenter.default

        guard let scrollView = enclosingScrollView else {
            print("ScrollView not found")
            return
        }

        nc.addObserver(
            self,
            selector: #selector(scrollViewWillStartLiveScroll(notification:)),
            name: NSScrollView.willStartLiveScrollNotification,
            object: scrollView
        )

        nc.addObserver(
            self,
            selector: #selector(scrollViewDidEndLiveScroll(notification:)),
            name: NSScrollView.didEndLiveScrollNotification,
            object: scrollView
        )
    }

    @objc func scrollViewWillStartLiveScroll(notification: Notification) {
        #if DEBUG
        print("\(#function) ")
        #endif
        invalidate()
    }

    @objc func scrollViewDidEndLiveScroll(notification: Notification) {
        #if DEBUG
        print("\(#function) ")
        #endif
        invalidate()
    }

}
