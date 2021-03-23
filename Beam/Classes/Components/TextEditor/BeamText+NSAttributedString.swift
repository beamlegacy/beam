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
    static let hoverUnderlineColor = NSAttributedString.Key(rawValue: "beam_hoverUnderlineColor") // NSColor, default nil
}

extension BeamText {
    func buildAttributedString(fontSize: CGFloat, cursorPosition: Int, elementKind: ElementKind, mouseInteraction: MouseInteraction? = nil) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for range in ranges {
            var attributedString = NSMutableAttributedString(string: range.string, attributes: convert(attributes: range.attributes, fontSize: fontSize, elementKind: elementKind))
            if let mouseInteraction = mouseInteraction, (range.position..<range.end).contains(mouseInteraction.range.lowerBound) {
                attributedString = updateAttributes(attributedString, withMouseInteraction: mouseInteraction)
            }

            addImageToLink(attributedString, range, mouseInteraction: mouseInteraction)
            string.append(attributedString)
        }
        return string
    }

    private func updateAttributes(_ attributedString: NSMutableAttributedString, withMouseInteraction mouseInteraction: MouseInteraction) -> NSMutableAttributedString {
        if mouseInteraction.type == .hovered {
            attributedString.enumerateAttribute(.hoverUnderlineColor, in: attributedString.wholeRange, options: []) { (value, range, _) in
                if let value = value {
                    attributedString.removeAttribute(.underlineColor, range: range)
                    attributedString.addAttribute(.underlineColor, value: value, range: range)
                }
            }
        }
        return attributedString
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

        if emphasis {
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
            stringAttributes[.underlineColor] = NSColor.editorLinkDecorationColor
            stringAttributes[NSAttributedString.Key.hoverUnderlineColor] = NSColor.editorLinkColor
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

    private func isMouseHoveringLinkImage(_ mouseInteraction: MouseInteraction, in range: BeamText.Range) -> Bool {
        return mouseInteraction.type == .hovered && mouseInteraction.range.lowerBound == range.end
    }

    func addImageToLink(_ attributedString: NSMutableAttributedString, _ range: BeamText.Range, mouseInteraction: MouseInteraction?) {
        guard attributedString.length > 0 else { return }
        guard range.attributes.contains(where: { attrib -> Bool in attrib.rawValue == BeamText.Attribute.link("").rawValue }) else { return }
        let imageName = "editor-url"
        guard let image = NSImage(named: imageName) else { return }

        var color = NSColor.editorLinkDecorationColor
        if let mouseInt = mouseInteraction, isMouseHoveringLinkImage(mouseInt, in: range) {
            color = .editorLinkColor
        }
        let extentBuffer = UnsafeMutablePointer<ImageRunStruct>.allocate(capacity: 1)
        extentBuffer.initialize(to: ImageRunStruct(ascent: image.size.height, descent: 0, width: image.size.width, image: imageName, color: color))

        var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { _ in
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
