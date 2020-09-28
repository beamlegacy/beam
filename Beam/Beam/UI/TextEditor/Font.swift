//
//  Font.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//

import Foundation
import AppKit

public struct TextLineLayout {
    public var rect: NSRect
    public var line: CTLine
    public var range: Range<Int>
}

public typealias FontWeight = NSFont.Weight

    
public class Font {
    public var size: Float { return Float(font.pointSize) }
    public var name: String { return font.fontName }
    public private(set) var font: NSFont {
        didSet {
            self.darkFont = self.font
            self.lightFont = NSFontManager.shared.convertWeight(true, of:font)
        }
    }
    
    private var lightFont: NSFont
    private var darkFont: NSFont
    public var ctFont: CTFont {
//        if NSAppearance.current.darkMode {
//            return darkFont as CTFont
//        }
        return lightFont
    }
    private var _cgFont: CGFont?
    private var _darkMode = false
    private var cgFont: CGFont? {
//        if _darkMode != NSAppearance.current.darkMode {
//            _cgFont = nil
//        }
//
        if _cgFont == nil {
            _cgFont = CTFontCopyGraphicsFont(ctFont, nil)
        }
        
        return _cgFont
    }
    
    public var ascent: Float { get { return cgFont != nil ? size * Float(cgFont!.ascent) / unitsPerEm : 0 } }
    public var capHeight: Float { get { return cgFont != nil ? size * Float(cgFont!.capHeight) / unitsPerEm : 0 } }
    public var descent: Float { get { return cgFont != nil ? size * Float(cgFont!.descent) / unitsPerEm : 0 } }
    public var fontBBox: NSRect {
        get {
            if let f = cgFont {
                let em = size / unitsPerEm
                var r = f.fontBBox
                r.origin.x *= CGFloat(em)
                r.origin.y *= CGFloat(em)
                r.size.width *= CGFloat(em)
                r.size.height *= CGFloat(em)
                return r
            }
            else {
                return NSRect()
            }
        }
    }
    public var italicAngle: Float { get { return cgFont != nil ? size * Float(cgFont!.italicAngle) : 0 } }
    public var leading: Float { get { return cgFont != nil ? size * Float(cgFont!.leading) / unitsPerEm : 0 } }
    public var stemV: Float { get { return cgFont != nil ? size * Float(cgFont!.stemV) / unitsPerEm : 0 } }
    public var unitsPerEm: Float { get { return cgFont != nil ? Float(cgFont!.unitsPerEm) : 0 } }
    public var xHeight: Float { get { return cgFont != nil ? size * Float(cgFont!.xHeight) / unitsPerEm : 0 } }
    public var underlineThickness: Float { get { return size * Float(CTFontGetUnderlineThickness(ctFont))} }
    public var underlinePosition: Float { get { return size * Float(CTFontGetUnderlinePosition(ctFont)) } }

    public var descriptor: NSFontDescriptor {
        get {
            let f = ctFont as NSFont
            return f.fontDescriptor
        }
    }
    
    public init(_ font: NSFont) {
        self.font = font
        self.darkFont = self.font
        self.lightFont = NSFontManager.shared.convertWeight(true, of:font)
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

    public func draw(string: String, textWidth: Float) -> [TextLineLayout] {
        var layoutedLines = [TextLineLayout]()
        var rect = NSRect()
        if let f = cgFont {
            var glyphs: [CGGlyph] = []
            var positions: [CGPoint] = []
            
            let inverseFontSize = CGFloat(1 / size)
            
            var glyphCount = 0

            if string != "" {
                let attrs: [String:CTFont] = [kCTFontAttributeName as String : ctFont]
                let attrString = CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary)
                
                let path = CGPath(rect: CGRect(x: 0, y: 0, width: textWidth, height: 100000), transform: nil)
                let framesetter = CTFramesetterCreateWithAttributedString(attrString!)
                let frameAttributes: [String:String] = [:]
                let frame = CTFramesetterCreateFrame(framesetter,
                                            CFRange(),
                                            path,
                                            frameAttributes as CFDictionary)
                
                let lines = CTFrameGetLines(frame) as! [CTLine]
                for line in lines {
                    let range = CTLineGetStringRange(line)
                    // Get an array of glyph runs from the line
                    let runArray = CTLineGetGlyphRuns(line) as! [CTRun]
                    // loop through each run in the array
                    for run in runArray {
                        let runGlyphCount = CTRunGetGlyphCount(run)
                        glyphCount += runGlyphCount

                        for runGlyphIndex in 0..<runGlyphCount {
                            var glyphId: CGGlyph = 0
                            CTRunGetGlyphs(run, CFRangeMake(runGlyphIndex, 1), &glyphId);
                            
                            glyphs.append(glyphId)
                            
                            //                    var position:CGPoint = (glyphPositions?[runGlyphIndex])!
                            var position = CGPoint()
                            let range = CFRangeMake(runGlyphIndex, 1)
                            CTRunGetPositions(run, range, &position)
                            var bbox = CGRect()
                            f.getGlyphBBoxes(glyphs: &glyphId, count: 1, bboxes: &bbox)

                            let em = CGFloat(size) / CGFloat(f.unitsPerEm)
                            bbox.origin.x *= em
                            bbox.origin.y *= em
                            bbox.size.width *= em
                            bbox.size.height = max(bbox.size.height, CGFloat(f.ascent - f.descent))
                            bbox.size.height *= em

                            var box = bbox
                            box = box.offsetBy(dx: position.x, dy: position.y)
                            rect = rect.union(box)
                            
                            position.x *= inverseFontSize
                            position.y *= inverseFontSize
                            
                            positions.append(position)
                        }
                    }

                    let r = NSRange(range: range)
                    layoutedLines.append(TextLineLayout(rect:rect, line:line, range: r.location ..< r.location + r.length))
                }
            }

        }

        return layoutedLines
    }
    
    public static var main = Font.system(size: 12)
    
    public static func system(size: Float, weight : FontWeight = .regular) -> Font {
        let font = NSFont.systemFont(ofSize: CGFloat(size), weight: weight)
        let fn = font.fontName
        return Font(name: fn, size: size, weight: weight)
    }

    public static func == (lhs: Font, rhs: Font) -> Bool {
        return lhs.size == rhs.size &&
                lhs.name == rhs.name
    }
}
