//
//  TextEdit.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//  Copyright © 2020 Beam. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI
import simd

public struct BTextEdit: NSViewRepresentable {
    public func makeNSView(context: Context) -> BeamTextEdit {
        let v = BeamTextEdit(text: String.loremIpsum, font: Font.main)
        v.multiline = true
        return v
    }
    
    public func updateNSView(_ nsView: BeamTextEdit, context: Context) {
        
    }
    
    public typealias NSViewType = BeamTextEdit
    
    
}

public class BeamTextEdit : TextInputHandler {
    var font: Font
    var minimumWidth: Float = 400
    var maximumWidth: Float = 1024
    
    public override var frame: NSRect {
        didSet {
            updateRendering()
        }
    }
    
    public init(text: String = "", font: Font = Font.main) {
        self.font = font
        super.init(text: text)
        updateRendering()
        
        initBlinking()
    }
    
    public init(text: String = "", font: Font = Font.main, color: NSColor) {
        self.font = font
        self.color = color
        super.init(text: text)
        updateRendering()
        
        initBlinking()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var animate = false { didSet {
        // TODO: implement animating the cursor
    }
    }
    
    func initBlinking() {
        let defaults = UserDefaults.standard
        let von = defaults.double(forKey:"NSTextInsertionPointBlinkPeriodOn")
        onBlinkTime = von == 0 ? onBlinkTime : von * 1000
        let voff = defaults.double(forKey:"NSTextInsertionPointBlinkPeriodOff")
        offBlinkTime = voff == 0 ? offBlinkTime : voff * 1000
        self.animate = true
    }
    
    var color = NSColor.textColor
    var disabledColor = NSColor.disabledControlTextColor
    var selectionColor = NSColor.selectedControlColor
    var markedColor = NSColor.unemphasizedSelectedTextColor
    var alpha: Float = 1.0
    var blendMode: CGBlendMode = .normal
    
    var hMargin: Float = 2 { didSet { invalidateLayout() } }
    var vMargin: Float = 0 { didSet { invalidateLayout() } }
    
    private var layouts: [TextLineLayout] = []
    private var cursorRect = NSRect()
    
    //    override public var intrinsicContentSize: NSSize {
    //        updateTextRendering()
    //        var r = NSRect()
    //        for l in layouts {
    //            r.size.width = max(r.width, l.rect.width)
    //            r.size.height += l.rect.height
    //        }
    //        return r.size
    //    }
    
    public func drawMarking(_ context: CGContext, _ start: Int, _ end: Int, _ color: NSColor) {
        context.beginPath()
        let startLine = lineAt(start)!
        let endLine = lineAt(end)!
        let line1 = layouts[startLine]
        let line2 = layouts[endLine]
        var _x2 = CGFloat(0)
        let xStart = CTLineGetOffsetForStringIndex(line1.line, CFIndex(start - lines[startLine].lowerBound), &_x2)
        let xEnd = CTLineGetOffsetForStringIndex(line2.line, CFIndex(end - lines[endLine].lowerBound), &_x2)
        
        //        let fill =  Fill()
        //        fill.setColor(resolve(color))
        context.setFillColor(color.cgColor)
        
        var e = xEnd
        if startLine != endLine {
            e = CGFloat(frame.width)
        }
        
        let markRect = NSRect(x: hMargin + Float(xStart), y: Float(line1.rect.minY) + fHeight * Float(startLine), width: Float(e - xStart), height: fHeight )
        //        var markShape = CGPath(rect: markRect, transform: nil)
        //        list.draw(shape: markShape, fill: fill, alpha: 1.0, blendMode: .normal)
        context.addRect(markRect)
        
        if startLine + 1 <= endLine {
            let markRect = NSRect(x: hMargin + Float(0), y: Float(line1.rect.maxY) + fHeight * Float(startLine), width: Float(frame.width), height: fHeight * Float(endLine - startLine - 1) )
            //            markShape.setRect(markRect.cgRect)
            context.addRect(markRect)
            //            list.draw(shape: markShape, fill: fill, alpha: 1.0, blendMode: .normal)
        }
        
        if startLine + 1 <= endLine {
            let markRect = NSRect(x: hMargin + Float(0), y: Float(line1.rect.maxY) + fHeight * Float(endLine - 1), width: Float(xEnd), height: fHeight)
            //            markShape.setRect(markRect.cgRect)
            //            list.draw(shape: markShape, fill: fill, alpha: 1.0, blendMode: .normal)
            context.addRect(markRect)
        }
        
        context.drawPath(using: .fill)
    }
    
    public func draw(in context: CGContext) {
        updateTextRendering()
        
        let cursorLine = lineAt(cursorPosition)
        
        //Draw Selection:
        if !markedTextRange.isEmpty {
            drawMarking(context, markedTextRange.lowerBound, markedTextRange.upperBound, markedColor)
        } else if !selectedTextRange.isEmpty {
            drawMarking(context, selectedTextRange.lowerBound, selectedTextRange.upperBound, selectionColor)
        }
        
        var Y = Float(0)
        //        let y = Y + ((rect.height - vMargin * 2) - fHeight * Float(lines.count)) / 2
        
        for l in layouts  {
            //let pos = cursorPosition
            //var x2 = CGFloat(0)
            //let x1 = cursorLine == i ? CTLineGetOffsetForStringIndex(l.line, CFIndex(pos - lines[i].lowerBound), &x2) : 0
            
            context.saveGState()
            
            //            print("rect \(rect.size)\n\ty \(y) - height \(height) - ascent \(font.ascent) - descent \(font.descent) - capHeight \(font.capHeight)\n\tBBox \(font.fontBBox)\n\tleading \(font.leading) - size \(font.size) - unitsPerEM \(font.unitsPerEm) - stemV \(font.stemV) - xHeight \(font.xHeight)\n")
            
            context.translateBy(x: CGFloat(hMargin), y: CGFloat(Y + fHeight + font.descent))
            context.scaleBy(x: 1, y: -1)
            
            for run in CTLineGetGlyphRuns(l.line) as! [CTRun] {
                CTRunDraw(run, context, CFRange())
            }
            //            context.addPath(l.shape)
            //            let s = CGFloat(font.size)
            //            context.scaleBy(x: s, y: s)
            //            context.drawPath(using: .eoFill)
            //            list.draw(displayList: self.lists[i])
            
            context.restoreGState()
            
            Y += fHeight
        }
        
        // Draw cursor
        if let cursorLine = cursorLine, hasFocus && blinkPhase  {
            var x2 = CGFloat(0)
            let x1 = CTLineGetOffsetForStringIndex(layouts[cursorLine].line, CFIndex(cursorPosition - lines[cursorLine].lowerBound), &x2)
            cursorRect = NSRect(x: hMargin + Float(x1), y: Float(cursorLine) * fHeight, width: 1.5, height: fHeight )
            
            context.beginPath()
            context.addRect(cursorRect)
            //let fill = RBFill()
            if enabled {
                context.setFillColor(color.cgColor)
            } else {
                context.setFillColor(disabledColor.cgColor)
            }
            
            //list.draw(shape: shape, fill: fill, alpha: 1.0, blendMode: .normal)
            context.drawPath(using: .fill)
        }
    }
    
    var invalidatedTextRendering = true
    func invalidateTextRendering() {
        invalidatedTextRendering = true
        invalidateLayout()
    }
    
    func updateTextRendering(forceWidth: Float? = nil) {
        if invalidatedTextRendering {
            layouts = []
            let textWidth = forceWidth ?? (minimumWidth ... maximumWidth).clamp(Float(frame.size.width))
            
            for lrange in lines {
                let layoutedLines = font.draw(string: text.substring(range: lrange), textWidth: textWidth)
                if  !layoutedLines.isEmpty {
                    for var l in layoutedLines {
                        l.rect.size.width += CGFloat(hMargin)
                        l.rect.size.height += CGFloat(vMargin)
                        let start = lrange.lowerBound + l.range.lowerBound
                        l.range = start ..<  start + l.range.count
                        layouts.append(l)
                    }
                } else {
                    // empty lines must be faked:
                    let attrs: [String:CTFont] = [kCTFontAttributeName as String : font.ctFont]
                    let attrString = CFAttributedStringCreate(nil, "" as CFString, attrs as CFDictionary)
                    let line = CTLineCreateWithAttributedString(attrString!)
                    
                    layouts.append(TextLineLayout(rect: NSRect(x: 0, y: 0, width: Float(1), height: Float(font.ascent - font.descent)), line: line, range: lrange))
                }
            }
        }
        invalidatedTextRendering = false
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current?.cgContext {
            self.draw(in: context)
        }
    }
    
    override public func updateRendering() {
        invalidateTextRendering()
    }
    
    enum DragMode {
        case none
        case select(Int)
    }
    var dragMode = DragMode.none
    
    public override func reBlink() {
        blinkPhase = true
        blinkTime = CFAbsoluteTimeGetCurrent() + onBlinkTime
        invalidate()
    }
    
    public func positionAt(_ point: simd_float2) -> Int {
        let x = point.x
        let y = point.y
        
        if y >= Float(frame.height) {
            return text.count
        }
        if y < 0 {
            return 0
        }
        
        let i = lineAt(point)
        let l = layouts[i]
        let fHeight = Float(font.ascent - font.descent)
        let p = CTLineGetStringIndexForPosition(l.line, CGPoint(x: CGFloat(x - hMargin), y: CGFloat(y - Float(i) * fHeight)))
        if p == -1 {
            return lines[i].lowerBound
        }
        return lines[i].lowerBound + p
    }
    
    var fHeight: Float { Float(font.ascent - font.descent) }
    
    public func lineAt(_ point: simd_float2) -> Int {
        let y = point.y
        if y >= Float(frame.height) {
            let v = layouts.count - 1
            return max(v, 0)
        }
        else if y < 0 {
            return 0
        }
        
        return min(Int(y / fHeight), lines.count - 1)
    }
    
    override public func mouseDown(with event: NSEvent) {
        //       window?.makeFirstResponder(self)
        if event.clickCount == 1 {
            reBlink()
            
            let point = self.convert(event.locationInWindow, from: nil)
            let p = positionAt(simd_float2(x: Float(point.x), y: Float(point.y)))
            dragMode = .select(p)
            cursorPosition = p
            selectedTextRange = text.clamp(cursorPosition..<cursorPosition)
            invalidate()
        } else {
            doCommand(.selectAll)
        }
    }
    
    public func rectAt(_ position: Int) -> NSRect {
        updateTextRendering()
        if let line = lineAt(position)  {
            var x2 = CGFloat(0)
            let x1 = CTLineGetOffsetForStringIndex(layouts[line].line, CFIndex(cursorPosition - lines[line].lowerBound), &x2)
            return NSRect(x: hMargin + Float(x1), y: Float(line) * fHeight, width: 1.5, height: fHeight )
        }
        
        return NSRect()
    }
    
    public override func mouseMoved(with event: NSEvent) {
        //        print("mouseMoved \(event)")
        super.mouseMoved(with: event)
    }
    
    override public func setHotSpotToCursorPosition() {
        setHotSpot(rectAt(cursorPosition))
    }
    
    override public func mouseDragged(with event: NSEvent) {
        //        window?.makeFirstResponder(self)
        
        let point = self.convert(event.locationInWindow, from: nil)
        let p = positionAt(simd_float2(x: Float(point.x), y: Float(point.y)))
        cursorPosition = p
        
        switch dragMode {
        case .none:
            break
        case .select(let o):
            if p < o {
                selectedTextRange = text.clamp(cursorPosition..<o)
            } else {
                selectedTextRange = text.clamp(o..<cursorPosition)
            }
            break
        }
        invalidate()
    }
    
    override public func mouseUp(with event: NSEvent) {
        dragMode = .none
        super.mouseUp(with: event)
    }
    
    public override var acceptsFirstResponder : Bool { return true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let w = newWindow {
            w.acceptsMouseMovedEvents = true
        }
    }
    
    public override func becomeFirstResponder() -> Bool {
        blinkPhase = true
        invalidate()
        return super.becomeFirstResponder()
    }
    public override func resignFirstResponder() -> Bool {
        blinkPhase = true
        cancelSelection()
        invalidate()
        return super.resignFirstResponder()
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
