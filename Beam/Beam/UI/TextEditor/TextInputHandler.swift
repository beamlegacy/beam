//
//  TextInputHandler.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//  Copyright © 2020 Beam. All rights reserved.
//

import Foundation
import AppKit
import Combine

public class TextInputHandler: NSView, NSTextInputClient {
    @Published var text : String = "" { didSet { updateLines(); updateRendering() } }
    var lines: [Range<Int>] = []
    @Published var selectedTextRange: Range<Int> {
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
        }
    }
    
    var selectedText: String {
        get {
            return text.substring(range: selectedTextRange)
        }
    }

    public func setHotSpot(_ spot: NSRect) {
        if let sv = superview as? NSScrollView {
            sv.scrollToVisible(spot)
        }
    }
    
    public func setHotSpotToCursorPosition() {
        assert(false) // Should be implemented in a subclass
    }

    
    public var activated: () -> Void = { }
    public var activateOnEnter = true
    public var activateOnLostFocus = true
    public var multiline = true { didSet { updateLines(); invalidateLayout() } }
    public var useFocusRing = false

    public func invalidateLayout() {
        invalidateIntrinsicContentSize()
        //assert(false) // implement whatever is needed to relayout this view
    }
    
    public func invalidate() {
        setNeedsDisplay(bounds)
        //assert(false) // implement whatever is needed to redraw this view
    }
    
    public init(text: String) {
        self.text = text
        selectedTextRange = 0..<0
        markedTextRange = 0..<0
        cursorPosition = 0
        super.init(frame: NSRect())
        _inputContext = NSTextInputContext(client: self)
        useFocusRing = false
        updateLines()
        if lines.count > 1 {
            activateOnEnter = false
        }
    }
    
    private var _inputContext: NSTextInputContext!
    public override var inputContext: NSTextInputContext? {
        return _inputContext
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        text.replaceSubrange(text.range(from:range), with: string)
        cursorPosition = range.upperBound
        cancelSelection()
        markedTextRange = range
        if markedTextRange.isEmpty {
            markedTextRange = text.clamp(markedTextRange.lowerBound ..< (markedTextRange.upperBound + string.count))
        }
        self.selectedTextRange = markedTextRange
        cursorPosition = self.selectedTextRange.upperBound
        reBlink()
        updateLines()
        updateRendering()
    }

    public func unmarkText() {
        markedTextRange = 0..<0
    }

    public func insertText(string: String, replacementRange: Range<Int>) {
        let c = string.count
        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !selectedTextRange.isEmpty {
            range = selectedTextRange
        }
        
        let r = text.range(from:range)
        text.replaceSubrange(r, with: string)
        cursorPosition = range.lowerBound + c
        cancelSelection()
        reBlink()
        updateLines()
        updateRendering()
    }
    
    public func characterIndexAt(_ x: Float, _ y: Float) -> Int {
        //TODO compute the actual rect and resulting range with Font/RBFont
        return 0
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        //TODO compute the actual rect and resulting range with Font/RBFont
        return (NSRect(), range)
    }
    
    public func updateLines() {
        lines = []
        if multiline {
            let _lines = text.split(omittingEmptySubsequences: false) { $0.isNewline }
            for l in _lines {
                lines.append(text.position(at: l.startIndex) ..< text.position(at: l.endIndex))
            }
        } else {
            lines.append(text.position(at: text.startIndex) ..< text.position(at: text.endIndex))
        }
//        if lines.count > 1 {
//            //print("text: \(text)\nlines: \(lines)")
//            for (i,l) in lines.enumerated() {
//                let str = text.substring(from: l.startIndex, to: l.endIndex)
//                //print("str[\(i)]: \(str)")
//            }
//        }
    }
    
    public func updateRendering() {
        assert(false) // To be implemented in the sub classes
    }

    public func reBlink() {
    }
    
    public var enabled = true
    
    @Published var hasFocus = false
    public override func becomeFirstResponder() -> Bool {
        hasFocus = true
        return true
    }
    public override func resignFirstResponder() -> Bool {
        if activateOnLostFocus {
            activated()
        }
        hasFocus = false
        return true
    }

    override open func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        let command = event.modifierFlags.contains(.command)

        if self.hasFocus {
            if let k = event.specialKey {
                switch k {
                case .enter: fallthrough
                case .carriageReturn:
                    if activateOnEnter {
                        if command && multiline {
                            doCommand(.insertNewline)
                        } else {
                            activated()
                        }
                    } else if multiline {
                        doCommand(.insertNewline)
                    }
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
                    break
                }
            }

            if event.keyCode == 117 { // delete
                doCommand(.deleteForward)
                return
            }

            if event.keyCode == 53 { // escape
                cancelSelection()
                return
            }
            

            if let ch = event.charactersIgnoringModifiers {
                if ch == "a" {
                    if command {
                        doCommand(.selectAll)
                        return
                    }
                }
            }

        }
        inputContext?.handleEvent(event)
        super.keyDown(with: event)
    }
    

}

// Command system
extension TextInputHandler {
    public enum Command {
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
        selectedTextRange = text.wholeRange
        cursorPosition = selectedTextRange.upperBound
        invalidate()
    }
    
    func eraseSelection() {
        if !selectedTextRange.isEmpty {
            text.removeSubrange(text.range(from:selectedTextRange))
            cursorPosition = selectedTextRange.lowerBound
            if cursorPosition == NSNotFound {
                cursorPosition = text.count
            }
            cancelSelection()
            updateLines()
            updateRendering()
        }
    }

    
    public func doCommand(_ command: Command) {
        reBlink()
        switch command {
        case .moveForward:
            if selectedTextRange.isEmpty {
                if cursorPosition != text.count {
                    cursorPosition = text.position(after: cursorPosition)
                }
            }
            cancelSelection()
            invalidate()

        case .moveLeft:
            if selectedTextRange.isEmpty {
                cursorPosition = text.position(before: cursorPosition)
            }
            cancelSelection()
            invalidate()

        case .moveBackward:
            if selectedTextRange.isEmpty {
                cursorPosition = text.position(before: cursorPosition)
            }
            cancelSelection()
            invalidate()

        case .moveRight:
            if selectedTextRange.isEmpty {
                cursorPosition = text.position(after: cursorPosition)
            }
            cancelSelection()
            invalidate()
            break

        case .moveLeftAndModifySelection:
            if cursorPosition != 0 {
                let newCursorPosition = text.position(before: cursorPosition)
                if cursorPosition == selectedTextRange.lowerBound {
                    selectedTextRange = text.clamp(newCursorPosition..<selectedTextRange.upperBound)
                }
                else {
                    selectedTextRange = text.clamp(selectedTextRange.lowerBound..<newCursorPosition)
                }
                cursorPosition = newCursorPosition
                invalidate()
            }

        case .moveWordRight:
            text.enumerateSubstrings(in: text.index(at: cursorPosition)..<text.endIndex, options: .byWords) { (str, r1, r2, stop) in
                self.cursorPosition = self.text.position(at: r1.upperBound)
                stop = true
            }
            
            cancelSelection()
            invalidate()

        case .moveWordLeft:
            var range = text.startIndex ..< text.endIndex
            text.enumerateSubstrings(in: text.startIndex..<text.index(at: cursorPosition), options: .byWords) { (str, r1, r2, stop) in
                range = r1
            }

            let pos = text.position(at: range.lowerBound)

            if pos == cursorPosition {
                cursorPosition = 0
            } else {
                cursorPosition = pos
            }

            cancelSelection()
            invalidate()


        case .moveWordRightAndModifySelection:
            var newCursorPosition = cursorPosition
            text.enumerateSubstrings(in: text.index(at: cursorPosition)..<text.endIndex, options: .byWords) { (str, r1, r2, stop) in
                newCursorPosition = self.text.position(at: r1.upperBound)
                stop = true
            }
            
            extendSelection(to: newCursorPosition)

        case .moveWordLeftAndModifySelection:
            var range = text.startIndex ..< text.endIndex
            var newCursorPosition = cursorPosition
            text.enumerateSubstrings(in: text.startIndex..<text.index(at: cursorPosition), options: .byWords) { (str, r1, r2, stop) in
                range = r1
            }

            let pos = text.position(at: range.lowerBound)

            if pos == cursorPosition {
                newCursorPosition = 0
            } else {
                newCursorPosition = pos
            }

            extendSelection(to: newCursorPosition)

        case .moveRightAndModifySelection:
            if cursorPosition != text.count {
                extendSelection(to: text.position(after: cursorPosition))
            }

        case .moveToBeginningOfLine:
            if let l = lineAt(cursorPosition) {
                cursorPosition = lines[l].lowerBound
                cancelSelection()
                invalidate()
            }

        case .moveToEndOfLine:
            if let l = lineAt(cursorPosition) {
                cursorPosition = lines[l].upperBound
                cancelSelection()
                invalidate()
            }

        case .moveToBeginningOfLineAndModifySelection:
            if let l = lineAt(cursorPosition) {
                extendSelection(to: lines[l].lowerBound)
            }

        case .moveToEndOfLineAndModifySelection:
            if let l = lineAt(cursorPosition) {
                extendSelection(to: lines[l].upperBound)
            }

        case .moveUp:
            cursorPosition = positionAbove(cursorPosition)
            cancelSelection()
            invalidate()

        case .moveDown:
            cursorPosition = positionBelow(cursorPosition)
            cancelSelection()
            invalidate()

        case .moveUpAndModifySelection:
            extendSelection(to: positionAbove(cursorPosition))

        case .moveDownAndModifySelection:
            extendSelection(to: positionBelow(cursorPosition))


        case .selectAll:
            selectAll()

        case .deleteForward:
            if !selectedTextRange.isEmpty {
                text.removeSubrange(text.range(from:selectedTextRange))
                cursorPosition = selectedTextRange.lowerBound
                if cursorPosition == NSNotFound {
                    cursorPosition = text.count
                }
            }
            else if cursorPosition != text.count {
                text.remove(at: text.index(at:cursorPosition))
            }
            cancelSelection()
            updateLines()
            updateRendering()

        case .deleteBackward:
            if !selectedTextRange.isEmpty {
                text.removeSubrange(text.range(from:selectedTextRange))
                cursorPosition = selectedTextRange.lowerBound
                if cursorPosition == NSNotFound {
                    cursorPosition = text.count
                }
                cancelSelection()
            }
            else if cursorPosition != 0 && text.count != 0 {
                cursorPosition = text.position(before: cursorPosition)
                text.remove(at: text.index(at:cursorPosition))
            }
            cancelSelection()
            updateLines()
            updateRendering()

        case .insertNewline:
            if !multiline {
                return
            }
            
            if !selectedTextRange.isEmpty {
                text.removeSubrange(text.range(from:selectedTextRange))
                text.insert("\n", at: text.index(at: selectedTextRange.startIndex))
                cursorPosition = text.position(after: selectedTextRange.startIndex)
                if cursorPosition == NSNotFound {
                    cursorPosition = text.count
                }
                cancelSelection()
            } else if cursorPosition != 0 && text.count != 0 {
                text.insert("\n", at: text.index(at: cursorPosition))
                cursorPosition = text.position(after: cursorPosition)
            }
            cancelSelection()
            updateLines()
            updateRendering()

        default:
            break
        }
    }
    
    public func positionAbove(_ position: Int) -> Int {
        if let l = lineAt(position) {
            if l > 0 {
                let p = position - lines[l].lowerBound
                let l2 = lines[l - 1]
                return clamp(l2.lowerBound + p, l2.lowerBound, l2.upperBound)
            }
        }
        
        return 0
    }

    public func positionBelow(_ position: Int) -> Int {
        if let l = lineAt(position) {
            if l + 1 < lines.count {
                let p = position - lines[l].lowerBound
                let l2 = lines[l + 1]
                return clamp(l2.lowerBound + p, l2.lowerBound, l2.upperBound)
            }
        }
        
        return text.count
    }

    public func lineAt(_ index: Int) -> Int? {
        for (i, l) in lines.enumerated() {
            if index < l.lowerBound {
                return i - 1
            }
        }
        if !lines.isEmpty {
            return lines.count - 1
        }
        return nil
    }

    func extendSelection(to newCursorPosition: Int) {
        var r1 = selectedTextRange.lowerBound
        var r2 = selectedTextRange.upperBound
        if cursorPosition == r2 {
            r2 = newCursorPosition
        } else {
            r1 = newCursorPosition
        }
        if r1 < r2 {
            selectedTextRange = text.clamp(r1..<r2)
        } else {
            selectedTextRange = text.clamp(r2..<r1)
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
        insertText(string: string as! String, replacementRange: range)
    }
    
    
    /* The receiver inserts string replacing the content specified by replacementRange. string can be either an NSString or NSAttributedString instance. selectedRange specifies the selection inside the string being inserted; hence, the location is relative to the beginning of string. When string is an NSString, the receiver is expected to render the marked text with distinguishing appearance (i.e. NSTextView renders with -markedTextAttributes).
     */
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
//        print("setMarkedText \(string) at \(replacementRange) with selection \(selectedRange)")
        let str = string as! String
        setMarkedText(string: str, selectedRange: selectedTextRange.lowerBound..<selectedTextRange.upperBound, replacementRange:replacementRange.lowerBound..<replacementRange.upperBound)
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
        var r = range
        var rr = Range(range, in: text)
        if rr == nil {
            if range.lowerBound == 0x7FFFFFFFFFFFFFFF {
                rr = Range<String.Index>(uncheckedBounds: (lower: text.endIndex, upper: text.endIndex))
            }
        }

        actualRange?.assign(from: &r, count: 1)
        if let rrr = rr {
            return NSAttributedString(string: String(text[rrr]))
        }

        return nil
    }
    
    public func attributedString() -> NSAttributedString {
        return NSAttributedString(string: text)
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
        rc = convert (rc, to: nil);
        rc = window! .convertToScreen (rc);
        return rc
    }
    
    
    /* Returns the index for character that is nearest to point. point is in the screen coordinate system.
     */
    public func characterIndex(for point: NSPoint) -> Int {
//        print("characterIndex for \(point)")
        return characterIndexAt(Float(point.x), Float(point.y))
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


    @IBAction func paste(_ sender: Any) {
        if let s = NSPasteboard.general.string(forType: .string) {
            insertText(string: s, replacementRange: selectedTextRange)
        }
    }
}


///////////////
///
extension NSEvent.SpecialKey: CaseIterable {
    public static var allCases: [NSEvent.SpecialKey] {
        return [
            .upArrow,
            .downArrow,
            .leftArrow,
            .rightArrow,
            .f1,
            .f2,
            .f3,
            .f4,
            .f5,
            .f6,
            .f7,
            .f8,
            .f9,
            .f10,
            .f11,
            .f12,
            .f13,
            .f14,
            .f15,
            .f16,
            .f17,
            .f18,
            .f19,
            .f20,
            .f21,
            .f22,
            .f23,
            .f24,
            .f25,
            .f26,
            .f27,
            .f28,
            .f29,
            .f30,
            .f31,
            .f32,
            .f33,
            .f34,
            .f35,
            .insert,
            .deleteForward,
            .home,
            .begin,
            .end,
            .pageUp,
            .pageDown,
            .printScreen,
            .scrollLock,
            .pause,
            .sysReq,
            .`break`,
            .reset,
            .stop,
            .menu,
            .user,
            .system,
            .print,
            .clearLine,
            .clearDisplay,
            .insertLine,
            .deleteLine,
            .insertCharacter,
            .deleteCharacter,
            .prev,
            .next,
            .select,
            .execute,
            .undo,
            .redo,
            .find,
            .help,
            .modeSwitch,
            .enter,
            .backspace,
            .tab,
            .newline,
            .formFeed,
            .carriageReturn,
            .backTab,
            .delete,
            .lineSeparator,
            .paragraphSeparator
        ]
    }
}


