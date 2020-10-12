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

    public func draw(string: String, textWidth: Float) -> [TextLineLayout] {
        guard string != "" else { return [] }
        let attrs: [String: CTFont] = [kCTFontAttributeName as String: ctFont]
        guard let attrString = CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary) else { return [] }
        return draw(string: attrString, textWidth: textWidth)
    }

    public func draw(string: NSAttributedString, textWidth: Float) -> [TextLineLayout] {
        guard !string.string.isEmpty else { return [] }
        var layoutedLines = [TextLineLayout]()

        let path = CGPath(rect: CGRect(x: 0, y: 0, width: textWidth, height: 100000), transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let frameAttributes: [String: String] = [:]
        let frame = CTFramesetterCreateFrame(framesetter,
                                    CFRange(),
                                    path,
                                    frameAttributes as CFDictionary)

        //swiftlint:disable:next force_cast
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var y = CGFloat(0)
        for line in lines {
            let range = CTLineGetStringRange(line)
            var rect = CTLineGetBoundsWithOptions(line, [.includeLanguageExtents, .useHangingPunctuation])

            rect.origin.y = y
            y += rect.height
            let r = NSRange(range: range)
            layoutedLines.append(TextLineLayout(rect: rect, line: line, range: r.location ..< r.location + r.length))
        }

        return layoutedLines
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
