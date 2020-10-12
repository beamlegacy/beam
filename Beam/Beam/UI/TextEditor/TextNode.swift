//
//  TextNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 07/10/2020.
//
// swiftlint:disable file_length

import Foundation
import AppKit
import Down

protocol TextNodeBase {
    var children: [TextNode] { get set }
}

class TextNode: TextNodeBase {
    var text: String = "" {
        didSet {
            guard oldValue != text else { return }
            invalidateTextRendering()
        }
    }

    var _attributedString: NSAttributedString?
    var attributedString: NSAttributedString {
        if let s = _attributedString {
            return s
        }
        let down = Down(markdownString: text)
        do {
            let options = DownOptions.sourcePos
            let styler = DownStyler(configuration: DownStylerConfiguration())
            let visitor = BeamAttributedStringVisitor(sourceString: text, styler: styler, options: options, cursorPosition: cursorPosition)
            visitor.contextualSyntax = editor.contextualSyntax
            let res = try down.toAttributedStringBeam(visitor: visitor)
            _attributedString = res
            return res
        } catch {

        }
        return NSAttributedString()
}

    var font: Font { editor.font }

    var layouts: [TextLineLayout] = []
    var children: [TextNode] = [] {
        didSet {
            for c in children {
                if let p = c.parent, p !== self {
                    p.children.removeAll { n in
                        n === c
                    }
                }
                c.parent = self
            }
        }
    }

    var indexInParent: Int {
        return parent!.children.firstIndex(where: { n in n === self })!
    }

    func insert(node: TextNode, after existingNode: TextNode) {
        let pos = existingNode.indexInParent
        children.insert(node, at: pos + 1)
    }

    var color: NSColor { editor.color }
    var disabledColor: NSColor { editor.disabledColor }
    var selectionColor: NSColor { editor.selectionColor }
    var markedColor: NSColor { editor.markedColor }
    var alpha: Float { editor.alpha }
    var blendMode: CGBlendMode { editor.blendMode }

    var hMargin: Float { editor.hMargin }
    var vMargin: Float { editor.vMargin }

    var fHeight: Float { editor.fHeight }

    var selectedTextRange: Range<Int> { editor.selectedTextRange }
    var markedTextRange: Range<Int> { editor.markedTextRange }
    var cursorPosition: Int { editor.cursorPosition }
    var enabled: Bool { editor.enabled }

    var width: Float = 1024 {
        didSet {
            guard oldValue != width else { return }
            invalidateTextRendering()
        }
    }

    var textFrame = NSRect() // The rectangle of our text excluding children
    var frame = NSRect() // the total frame including text and children

    var offsetInParent: NSPoint {
        guard let p = parent else { return NSPoint() }
        var y = CGFloat(0)
        for c in p.children {
            guard c !== self else { return NSPoint(x: CGFloat(childInset), y: y) }
            y += c.frame.height
        }
        assert(false) // we should never reach that point
    }

    var offsetInDocument: NSPoint { // the position in the global document
        guard let p = parent else { return NSPoint() }
        let o1 = offsetInParent
        let o2 = p.offsetInParent
        return NSPoint(x: o1.x + o2.x, y: o1.y + o2.y)
    }

    var frameInDocument: NSRect {
        return NSRect(origin: offsetInDocument, size: frame.size)
    }

    var parent: TextNode?

    private var _editor: BeamTextEdit?
    var editor: BeamTextEdit {
        if let e = _editor {
            return e
        }
        assert(parent != nil)
        let p = parent!
        _editor = p.editor
        assert(_editor != nil)
        return _editor!
    }

    init() {

    }

    var isEditing: Bool { editor.node === self }
    var childInset = Float(40)

    private var needLayout = true
    func invalidateLayout() {
        needLayout = true
        guard let p = parent else { return }
        p.invalidateLayout()
    }

    public func draw(in context: CGContext, width: Float) {
        updateTextRendering()

        // draw debug:
//        context.setStrokeColor(NSColor.lightGray.cgColor)
//        context.stroke(frame)

        //Draw Selection:
        if isEditing {
            if !editor.markedTextRange.isEmpty {
                drawMarking(context, markedTextRange.lowerBound, markedTextRange.upperBound, markedColor)
            } else if !selectedTextRange.isEmpty {
                drawMarking(context, selectedTextRange.lowerBound, selectedTextRange.upperBound, selectionColor)
            }
        }

        var Y = Float(0)
        //        let y = Y + ((rect.height - vMargin * 2) - fHeight * Float(lines.count)) / 2

        for l in layouts {
            context.saveGState()

            //            print("rect \(rect.size)\n\ty \(y) - height \(height) - ascent \(font.ascent) - descent \(font.descent) - capHeight \(font.capHeight)\n\tBBox \(font.fontBBox)\n\tleading \(font.leading) - size \(font.size) - unitsPerEM \(font.unitsPerEm) - stemV \(font.stemV) - xHeight \(font.xHeight)\n")

            context.translateBy(x: l.rect.origin.x + CGFloat(hMargin), y: CGFloat(font.ascent) + l.rect.origin.y)
            context.scaleBy(x: 1, y: -1)

            //swiftlint:disable:next force_cast
            for run in CTLineGetGlyphRuns(l.line) as! [CTRun] {
                CTRunDraw(run, context, CFRange())
            }

            context.restoreGState()

            Y += fHeight
        }

        if isEditing {
            drawCursor(in: context)
        }

        let childrenWidth = width - childInset
        var y = self.textFrame.height
        for c in children {
            c.width = childrenWidth
            context.saveGState()
            context.translateBy(x: CGFloat(childInset), y: CGFloat(y))
            c.draw(in: context, width: childrenWidth)
            y += c.frame.height
            context.restoreGState()
        }
    }

    var invalidatedTextRendering = true
    func invalidateTextRendering() {
        invalidatedTextRendering = true
        _attributedString = nil
        invalidateLayout()
    }

    public func drawMarking(_ context: CGContext, _ start: Int, _ end: Int, _ color: NSColor) {
        context.beginPath()
        let startLine = lineAt(index: start)!
        let endLine = lineAt(index: end)!
        let line1 = layouts[startLine]
        let line2 = layouts[endLine]
        let xStart = offsetAt(index: start)
        let xEnd = offsetAt(index: end)

        context.setFillColor(color.cgColor)

        if startLine == endLine {
            // Selection begins and ends on the same line:
            let markRect = NSRect(x: hMargin + Float(xStart), y: Float(line1.rect.minY), width: Float(xEnd - xStart), height: Float(font.ascent - font.descent) + 1)
            context.addRect(markRect)
        } else {
            let markRect1 = NSRect(x: hMargin + Float(xStart), y: Float(line1.rect.minY), width: width - Float(xStart), height: Float(line1.rect.height) )
            context.addRect(markRect1)

            if startLine + 1 != endLine {
                // bloc doesn't end on the line directly below the start line, so be need to joind the start and end lines with a big rectangle
                let markRect2 = NSRect(x: 0, y: line1.rect.maxY, width: CGFloat(width), height: line2.rect.minY - line1.rect.maxY)
                context.addRect(markRect2)
            }

            let markRect3 = NSRect(x: 0, y: line2.rect.minY, width: xEnd, height: CGFloat(font.ascent - font.descent) + 1)
            context.addRect(markRect3)
        }

        context.drawPath(using: .fill)
    }

    func drawCursor(in context: CGContext) {
        // Draw cursor
        guard let cursorLine = lineAt(index: editor.cursorPosition), editor.hasFocus, editor.blinkPhase else { return }

//        var x2 = CGFloat(0)
        let line = layouts[cursorLine]
        let pos = cursorPosition
        let x1 = offsetAt(index: pos) // CTLineGetOffsetForStringIndex(line.line, CFIndex(pos), &x2)
        let cursorRect = NSRect(x: Float(x1), y: Float(line.rect.minY), width: 1.5, height: fHeight )

        context.beginPath()
        context.addRect(cursorRect)
        //let fill = RBFill()
        context.setFillColor(enabled ? color.cgColor : disabledColor.cgColor)

        //list.draw(shape: shape, fill: fill, alpha: 1.0, blendMode: .normal)
        context.drawPath(using: .fill)
    }

    func updateTextRendering() {
        guard invalidatedTextRendering else { return }
        layouts = []
        textFrame = NSRect()
        frame = NSRect(origin: CGPoint(), size: CGSize(width: Double(width), height: 0.0))

        if !text.isEmpty {
            let layoutedLines = font.draw(string: attributedString, textWidth: width)
            for var l in layoutedLines {
                l.rect.size.width += CGFloat(hMargin)
                l.rect.size.height += CGFloat(vMargin)
                layouts.append(l)

                textFrame.size.width = max(textFrame.size.width, l.rect.size.width)
                textFrame.size.height += l.rect.size.height
            }

            frame = textFrame
            frame.size.height = max(CGFloat(fHeight), frame.size.height)
            frame.size.width = CGFloat(width)
        }

        for c in children {
            c.updateTextRendering()
            frame.size.height += c.frame.height
        }

        invalidatedTextRendering = false
    }

    func nodeAt(point: CGPoint) -> TextNode? {
        guard frame.contains(point) else { return nil }
        if textFrame.contains(point) {
            return self
        }

        var y = point.y - textFrame.height
        for c in children {
            let p = CGPoint(x: point.x - CGFloat(childInset), y: y)
            if let res = c.nodeAt(point: p) {
                return res
            }
            y -= c.frame.height
        }
        return nil
    }

    public func lineAt(point: NSPoint) -> Int {
        let y = point.y
        if y >= frame.height {
            let v = layouts.count - 1
            return max(v, 0)
        } else if y < 0 {
            return 0
        }

        for (i, l) in layouts.enumerated() where point.y < l.rect.minY {
            return i - 1
        }

        return min(Int(y / CGFloat(fHeight)), layouts.count - 1)
    }

    public func lineAt(index: Int) -> Int? {
        for (i, l) in layouts.enumerated() where index < l.range.lowerBound {
            return i - 1
        }
        if !layouts.isEmpty {
            return layouts.count - 1
        }
        return nil
    }

    func rangeFor(line: Int) -> Range<Int>? {
        return layouts[line].range
    }

    public func position(at index: String.Index) -> Int {
        return text.position(at: index)
    }

    public func position(after index: Int) -> Int {
        let displayIndex = displayIndexFor(sourceIndex: index)
        let newDisplayIndex = attributedString.string.position(after: displayIndex)
        let newIndex = sourceIndexFor(displayIndex: newDisplayIndex)
        return newIndex
    }

    public func position(before index: Int) -> Int {
        let displayIndex = displayIndexFor(sourceIndex: index)
        let newDisplayIndex = attributedString.string.position(before: displayIndex)
        let newIndex = sourceIndexFor(displayIndex: newDisplayIndex)
        return newIndex
    }

    public func positionAt(point: NSPoint) -> Int {
        let line = lineAt(point: point)
        let l = layouts[line]
        let displayIndex = CTLineGetStringIndexForPosition(l.line, point)

        return sourceIndexFor(displayIndex: displayIndex)
    }

    func sourceIndexFor(displayIndex: Int) -> Int {
        var range = NSRange()
        let attributes = attributedString.attributes(at: displayIndex, effectiveRange: &range)
        let ranges = attributes.filter({ $0.key == .sourceRange })
        guard let position = ranges.first else { return 0 }
        guard let number = position.value as? NSNumber else { return 0 }
        return displayIndex - range.location + number.intValue
    }

    func displayIndexFor(sourceIndex: Int) -> Int {
        var found_range = NSRange()
        var found_position = 0
        attributedString.enumerateAttribute(.sourceRange, in: NSRange(location: 0, length: attributedString.length), options: .longestEffectiveRangeNotRequired) { value, range, stop in
            //swiftlint:disable:next force_cast
            let position = value as! NSNumber
            let p = position.intValue
            if p <= sourceIndex {
                found_range = range
                found_position = p
            }
            if p >= sourceIndex {
                stop.pointee = true
            }
        }

        return found_range.lowerBound + (sourceIndex - found_position)
    }

    public func offsetAt(index: Int) -> CGFloat {
        let displayIndex = displayIndexFor(sourceIndex: index)
        guard let line = lineAt(index: displayIndex) else { return 0 }
        let layoutLine = layouts[line]
        let positionInLine = displayIndex
        let result = CTLineGetOffsetForStringIndex(layoutLine.line, CFIndex(positionInLine), nil)
//        print("offsetAt(\(index)) -> \(result) [displayindex = \(displayIndex)]")
        return result
    }

    public func positionAbove(_ position: Int) -> Int {
        guard let l = lineAt(index: position), l > 0 else { return 0 }
        guard let lineRange = rangeFor(line: l) else { return 0 }
        let positionInLine = position - lineRange.lowerBound
        let lineAbove = l - 1
        guard let lineAboveRange = rangeFor(line: lineAbove) else { return 0 }
        return clamp(lineAboveRange.lowerBound + positionInLine, lineAboveRange.lowerBound, lineAboveRange.upperBound)
    }

    public func positionBelow(_ position: Int) -> Int {
        let end = text.position(at: text.endIndex)
        guard let l = lineAt(index: position), l < layouts.count - 1 else { return end }
        guard let lineRange = rangeFor(line: l) else { return end }
        let positionInLine = position - lineRange.lowerBound
        let lineBelow = l + 1
        guard let lineBelowRange = rangeFor(line: lineBelow) else { return end }
        return clamp(lineBelowRange.lowerBound + positionInLine, lineBelowRange.lowerBound, lineBelowRange.upperBound)
    }

    public func isOnFirstLine(_ position: Int) -> Bool {
        guard let l = lineAt(index: position) else { return false }
        return l == 0
    }

    public func isOnLastLine(_ position: Int) -> Bool {
        guard let l = lineAt(index: position) else { return false }
        return l == layouts.count - 1
    }

    public func rectAt(_ position: Int) -> NSRect {
        updateTextRendering()
        guard let l = lineAt(index: position) else { return NSRect() }
        let x1 = offsetAt(index: position)
        return NSRect(x: hMargin + Float(x1), y: Float(l) * fHeight, width: 1.5, height: fHeight )
    }
}
