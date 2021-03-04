//
//  BeamText+NSAttributedString.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import AppKit

extension NSAttributedString.Key {
    static let source = NSAttributedString.Key(rawValue: "beamSource")
}

extension BeamText {
    func buildAttributedString(fontSize: CGFloat, cursorPosition: Int, elementKind: ElementKind) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for range in ranges {
            let attributedString = NSMutableAttributedString(string: range.string, attributes: convert(attributes: range.attributes, fontSize: fontSize, elementKind: elementKind))

            addImageToLink(attributedString, range)
            string.append(attributedString)
        }
        return string
    }

    private func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        Self.font(size, weight: weight)
    }

    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private func font(fontSize: CGFloat, strong: Bool, emphasis: Bool, elementKind: ElementKind) -> NSFont {
        Self.font(fontSize: fontSize, strong: strong, emphasis: emphasis, elementKind: elementKind)
    }

    static func font(fontSize: CGFloat, strong: Bool, emphasis: Bool, elementKind: ElementKind) -> NSFont {
        var quote = false
        var font = NSFont(name: "Inter-Regular", size: fontSize)

        switch elementKind {
        case .bullet:
            break
        case .code:
            break
        case .heading:
            font = NSFont(name: "Inter-Medium", size: fontSize)
        case .quote:
            quote = true
        }

        if strong {
            font = NSFont(name: "Inter-Bold", size: fontSize)
            if font == nil {
                font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .boldFontMask)
            }
        }

        if emphasis || quote {
            font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask)
        }

        guard let actualFont = font else { return NSFont.systemFont(ofSize: fontSize) }

        return actualFont
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func convert(attributes: [Attribute], fontSize: CGFloat, elementKind: ElementKind) -> [NSAttributedString.Key: Any] {
        var stringAttributes = [NSAttributedString.Key: Any]()
        var strong = false
        var emphasis = false
        var strikethrough = false
        var color = NSColor.editorTextColor
//        var quoteLevel: Int
//        var quoteTitle: String?
//        var quoteSource: String?
        var source: String?
        var webLink: String?
        var internalLink: String?

        for attribute in attributes {
            switch attribute {
            case .strong:
                strong = true
            case .emphasis:
                emphasis = true
            case .source(let link):
                source = link
            case .link(let link):
                color = NSColor.editorLinkColor
                webLink = link
            case .internalLink(let link):
                color = NSColor.editorBidirectionalLinkColor
                internalLink = link
            case .strikethrough:
                strikethrough = true
            }
        }

        stringAttributes[.font] = font(fontSize: fontSize, strong: strong, emphasis: emphasis, elementKind: elementKind)
        stringAttributes[.foregroundColor] = color
        if let link = webLink {
            if let url = URL(string: link) {
                stringAttributes[.link] = url as NSURL
            } else if let url = URL(string: link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!) {
                stringAttributes[.link] = url as NSURL
            }

            stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.underlineColor] = NSColor.underlineAndstrikethroughColor
        } else if let link = internalLink {
            stringAttributes[.link] = link
        }

        if strikethrough {
            stringAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.strikethroughColor] = NSColor.underlineAndstrikethroughColor
        }

        if let source = source {
            stringAttributes[.source] = source
        }

        return stringAttributes
    }

    func addImageToLink(_ attributedString: NSMutableAttributedString, _ range: BeamText.Range) {
        guard attributedString.length > 0 else { return }
        guard range.attributes.contains(where: { attrib -> Bool in attrib.rawValue == BeamText.Attribute.link("").rawValue }) else { return }
        guard let image = NSImage(named: "editor-url") else { return }

        let extentBuffer = UnsafeMutablePointer<ImageRunStruct>.allocate(capacity: 1)
        extentBuffer.initialize(to: ImageRunStruct(ascent: image.size.height, descent: 0, width: image.size.width, image: "editor-url"))

        var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (pointer) in
        }, getAscent: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: ImageRunStruct.self)
            return d.pointee.ascent
        }, getDescent: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: ImageRunStruct.self)
            return d.pointee.descent
        }, getWidth: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: ImageRunStruct.self)
            return d.pointee.width
        })

        let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)

        let attrDictionaryDelegate = [(kCTRunDelegateAttributeName as NSAttributedString.Key): (delegate as Any)]
        let fakeGlyph = NSMutableAttributedString(string: " ", attributes: attrDictionaryDelegate)
        _ = fakeGlyph.addAttributes(attributedString.attributes(at: 0, effectiveRange: nil))
        fakeGlyph.removeAttribute(.underlineStyle, range: fakeGlyph.wholeRange)
        fakeGlyph.removeAttribute(.underlineColor, range: fakeGlyph.wholeRange)
        attributedString.append(fakeGlyph)
    }

}
