//
//  Font.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//

import Foundation
import AppKit

public typealias FontWeight = NSFont.Weight

public class TextLine {
    init(ctLine: CTLine) {
        self.ctLine = ctLine
    }

    var ctLine: CTLine
    var range: Range<Int> {
        let r = CTLineGetStringRange(ctLine)
        return r.location ..< r.location + r.length
    }
    var glyphCount: Int {
        CTLineGetGlyphCount(ctLine)
    }

    struct Bounds {
        var ascent: Float
        var descent: Float
        var leading: Float
        var width: Float
    }
    var typographicBounds: Bounds {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let w = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
        return Bounds(ascent: Float(ascent), descent: Float(descent), leading: Float(leading), width: Float(w))
    }

    var frame = NSRect()

    var bounds: NSRect { bounds() }
    func bounds(options: CTLineBoundsOptions = []) -> NSRect {
        return CTLineGetBoundsWithOptions(ctLine, options)
    }

    var traillingWhiteSpaceWidth: Float {
        Float(CTLineGetTrailingWhitespaceWidth(ctLine))
    }

    var imageBounds: NSRect {
        return CTLineGetImageBounds(ctLine, nil)
            .offsetBy(dx: frame.origin.x, dy: frame.origin.y)
    }

    func stringIndexFor(position: NSPoint) -> Int {
        var previous = Float(0)
        for (i, caret) in carets.enumerated() {
            let offset = caret.offset
            let middle = CGFloat(0.5 * (offset + previous))
            if middle > position.x {
                return max(0, i - 1)
            }
            previous = offset
        }
        return carets.count - 1
    }

    func isAfterEndOfLine(_ point: NSPoint) -> Bool {
        return (point.x - frame.origin.x) >= frame.maxX
    }

    func isBeforeStartOfLine(_ point: NSPoint) -> Bool {
        return (point.x - frame.origin.x) <= frame.minX
    }

    func offsetFor(index: Int) -> Float {
        guard index < carets.count else { return Float(frame.maxX) }
        return carets[index].offset
    }

    struct Caret {
        var offset: Float
        var index: Int
        var isLeadingEdge: Bool
    }

    lazy var carets: [Caret] = {
        let carets = self.allCarets
        var c: [Caret] = carets.compactMap { caret -> Caret? in
            caret.isLeadingEdge ? caret : nil
        }
        guard let last = carets.last else { return c }
        c.append(last)
        return c
    }()

    var allCarets: [Caret] {
        var c = [Caret]()
        CTLineEnumerateCaretOffsets(ctLine) { (offset, index, leading, _) in
            c.append(Caret(offset: Float(self.frame.origin.x) + Float(offset), index: index, isLeadingEdge: leading))
        }

        return c
    }

    var runs: [CTRun] {
        //swiftlint:disable:next force_cast
        CTLineGetGlyphRuns(ctLine) as! [CTRun]
    }

    func draw(_ context: CGContext) {
        context.saveGState()
        context.textPosition = NSPoint()//line.frame.origin
        context.translateBy(x: frame.origin.x, y: frame.origin.y)
        context.scaleBy(x: 1, y: -1)

        CTLineDraw(ctLine, context)

        // draw strikethrough if needed:
        var offset = CGFloat(0)
        for run in runs {
            var ascent = CGFloat(0)
            var descent = CGFloat(0)

            let width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil)

            if let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any], attributes[.strikethroughStyle] as? NSNumber != nil {
                let strikeThroughColor = attributes[.strikethroughColor] as? NSColor ?? NSColor.black

                context.setStrokeColor(strikeThroughColor.cgColor)

                let  y = CGFloat(roundf(Float(ascent / 3.0)))
                context.move(to: CGPoint(x: offset, y: y))
                context.addLine(to: CGPoint(x: offset + CGFloat(width), y: y))

                context.strokePath()
            }

            offset += CGFloat(width)
        }

        // Done!
        context.restoreGState()
    }

    var interlineFactor: CGFloat = 1.0
}

public class TextFrame {
    init(ctFrame: CTFrame, position: NSPoint, attributedString: NSAttributedString) {
        self.ctFrame = ctFrame
        self.position = position
        self.attributedString = attributedString

        layout()
    }

    var attributedString: NSAttributedString

    var debug: Bool { lines.count > 1 }
    var ctFrame: CTFrame
    var position: NSPoint
    var lines = [TextLine]()

    var range: Range<Int> {
        let r = CTFrameGetStringRange(ctFrame)
        return r.location ..< r.location + r.length
    }

    var visibleRange: Range<Int> {
        let r = CTFrameGetVisibleStringRange(ctFrame)
        return r.location ..< r.location + r.length
    }

    var path: CGPath {
        CTFrameGetPath(ctFrame)
    }

    private var paragraphSpacing: CGFloat {
        if !attributedString.string.isEmpty {
            if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: 0, longestEffectiveRange: nil, in: attributedString.wholeRange) as? NSParagraphStyle {
                return paragraphStyle.paragraphSpacing
            }
        }

        return 0
    }

    private var paragraphSpacingBefore: CGFloat {
        if !attributedString.string.isEmpty {
            if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: 0, longestEffectiveRange: nil, in: attributedString.wholeRange) as? NSParagraphStyle {
                return paragraphStyle.paragraphSpacingBefore
            }
        }

        return 0
    }

    var frame: NSRect {
        var minX = CGFloat(0)
        var maxX = CGFloat(0)
        var minY = CGFloat(0)
        var maxY = CGFloat(0)
        for l in lines {
            let r = l.frame
            minX = min(minX, r.minX)
            maxX = max(maxX, r.maxX)
            minY = min(minY, r.minY)
            maxY = max(maxY, r.maxY)
        }
        if let lastLine = lines.last {
            let lastFrame = lastLine.frame
            maxY = max(maxY, lastFrame.origin.y + lastFrame.height * lastLine.interlineFactor)
        }

        maxY += paragraphSpacing

        return NSRect(x: position.x + minX, y: position.y + minY, width: maxX - minX, height: maxY - minY)
    }

    func layout() {
        if lines.isEmpty {
            // swiftlint:disable:next force_cast
            lines = (CTFrameGetLines(ctFrame) as! [CTLine]).map {
                let line = TextLine(ctLine: $0)
                if let paragraphStyle = attributedString.attribute(.paragraphStyle, at: line.range.lowerBound, longestEffectiveRange: nil, in: NSRange(line.range)) as? NSParagraphStyle {
                    line.interlineFactor = paragraphStyle.lineHeightMultiple
                }
                return line
            }
        }
        if debug {
            //            print("start layout for \(lines.count) lines")
        }
        var lineOrigins = [CGPoint](repeating: CGPoint(), count: lines.count)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &lineOrigins)

        var Y = CGFloat(0)

        Y += paragraphSpacingBefore

        for i in lines.indices {
            let line = lines[i]
            let textPos = lineOrigins[i]
            let x = textPos.x
            //let y = f.maxY - textPos.y + CGFloat(line.bounds.descent)

            let y = Y // + CGFloat(line.bounds.ascent)

            line.frame = NSRect(x: position.x + x, y: position.y + y, width: line.bounds.width, height: line.bounds.height)

            Y += line.frame.height * line.interlineFactor
            //if debug {
            //print("     line[\(i)] frame \(line.frame) (textPos \(textPos)")
            //}
        }

        if debug {
            //print("layout frame \(frame)")
        }
    }

    func draw(_ context: CGContext) {
        if debug {
            //print("draw frame \(ctFrame)")
        }

        for line in lines {

            line.draw(context)
        }
    }
}

public class Font {
    public var size: Float { return Float(font.pointSize) }
    public var name: String { return font.fontName }
    public private(set) var font: NSFont {
        didSet {
            self.darkFont = self.font
            self.lightFont = NSFontManager.shared.convertWeight(true, of: font)
        }
    }

    private var lightFont: NSFont
    private var darkFont: NSFont
    public var ctFont: CTFont {
        return lightFont
    }
    private var _cgFont: CGFont?
    private var _darkMode = false
    private var cgFont: CGFont? {
        if _cgFont == nil {
            _cgFont = CTFontCopyGraphicsFont(ctFont, nil)
        }
        return _cgFont
    }

    public var ascent: Float { cgFont != nil ? size * Float(cgFont!.ascent) / unitsPerEm : 0 }
    public var capHeight: Float { cgFont != nil ? size * Float(cgFont!.capHeight) / unitsPerEm : 0 }
    public var descent: Float { cgFont != nil ? size * Float(cgFont!.descent) / unitsPerEm : 0 }
    public var fontBBox: NSRect {
        if let f = cgFont {
            let em = size / unitsPerEm
            var r = f.fontBBox
            r.origin.x *= CGFloat(em)
            r.origin.y *= CGFloat(em)
            r.size.width *= CGFloat(em)
            r.size.height *= CGFloat(em)
            return r
        } else {
            return NSRect()
        }
    }
    public var italicAngle: Float { return cgFont != nil ? size * Float(cgFont!.italicAngle) : 0 }
    public var leading: Float { return cgFont != nil ? size * Float(cgFont!.leading) / unitsPerEm : 0 }
    public var stemV: Float { return cgFont != nil ? size * Float(cgFont!.stemV) / unitsPerEm : 0 }
    public var unitsPerEm: Float { return cgFont != nil ? Float(cgFont!.unitsPerEm) : 0 }
    public var xHeight: Float { return cgFont != nil ? size * Float(cgFont!.xHeight) / unitsPerEm : 0 }
    public var underlineThickness: Float { return size * Float(CTFontGetUnderlineThickness(ctFont)) }
    public var underlinePosition: Float { return size * Float(CTFontGetUnderlinePosition(ctFont)) }

    public var descriptor: NSFontDescriptor { (ctFont as NSFont).fontDescriptor }

    public init(_ font: NSFont) {
        self.font = font
        self.darkFont = self.font
        self.lightFont = NSFontManager.shared.convertWeight(true, of: font)
    }

    public convenience init(name: String, size: Float, weight: FontWeight = .regular) {
        var attributes: [NSFontDescriptor.AttributeName: Any] = [:]
        attributes[NSFontDescriptor.AttributeName.name] = name

        attributes[NSFontDescriptor.AttributeName.traits] = [
            NSFontDescriptor.TraitKey.weight: weight
        ]

        let desc = NSFontDescriptor(fontAttributes: attributes)
        let f = NSFont(descriptor: desc, size: CGFloat(size))
        self.init(f!)
    }

    public func draw(string: String, textWidth: CGFloat) -> TextFrame {
        let attrs: [String: CTFont] = [kCTFontAttributeName as String: ctFont]
        let attrString = CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary)!
        return Self.draw(string: attrString, atPosition: NSPoint(), textWidth: textWidth)
    }

    class func draw(string: NSAttributedString, atPosition position: NSPoint, textWidth: CGFloat) -> TextFrame {
        assert(textWidth != 0)
        //        print("Font create frame with width \(textWidth) for string '\(string)'")
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake (0, 0),
            nil,
            CGSize(width: CGFloat(textWidth), height: CGFloat.greatestFiniteMagnitude),
            nil)
        //        print("TextFrame suggested size \(frameSize)")
        let path = CGPath(rect: CGRect(origin: position, size: frameSize), transform: nil)

        let frameAttributes: [String: Any] = [:]
        let frame = CTFramesetterCreateFrame(framesetter,
                                             CFRange(),
                                             path,
                                             frameAttributes as CFDictionary)

        //        print("TextFrame: \(frame)")

        let f = TextFrame(ctFrame: frame, position: position, attributedString: string)

        if f.debug {
            //            print("Font created frame \(f)")
        }
        return f
    }

    public static var main = Font.system(size: 12)

    public static func system(size: Float, weight: FontWeight = .regular) -> Font {
        let font = NSFont.systemFont(ofSize: CGFloat(size), weight: weight)
        let fn = font.fontName
        return Font(name: fn, size: size, weight: weight)
    }

    public static func == (lhs: Font, rhs: Font) -> Bool {
        return lhs.size == rhs.size &&
            lhs.name == rhs.name
    }
}
