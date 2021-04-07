//
//  BeamText+NSAttributedString.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import AppKit
import BeamCore

extension NSAttributedString.Key {
    static let source = NSAttributedString.Key(rawValue: "beamSource")
    static let hoverUnderlineColor = NSAttributedString.Key(rawValue: "beam_hoverUnderlineColor") // NSColor, default nil
}

extension BeamText {
    func buildAttributedString(fontSize: CGFloat, cursorPosition: Int, elementKind: ElementKind, mouseInteraction: MouseInteraction? = nil) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for range in ranges {
            var attributedString = NSMutableAttributedString(string: range.string, attributes: convert(attributes: range.attributes, fontSize: fontSize, elementKind: elementKind))
            if let mouseInteraction = mouseInteraction, (range.position...range.end).contains(mouseInteraction.range.upperBound) {
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
        var font = BeamFont.regular(size: fontSize).nsFont

        switch elementKind {
        case .bullet, .code, .quote:
            break
        case .heading:
            font = BeamFont.medium(size: fontSize).nsFont
        }

        if strong {
            font = BeamFont.bold(size: fontSize).nsFont
        }

        if emphasis {
            font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: fontSize), toHaveTrait: .italicFontMask)
        }

        return font
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func convert(attributes: [Attribute], fontSize: CGFloat, elementKind: ElementKind) -> [NSAttributedString.Key: Any] {
        var stringAttributes = [NSAttributedString.Key: Any]()
        var strong = false
        var emphasis = false
        var strikethrough = false
        var color = BeamColor.Generic.text.nsColor
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
                color = BeamColor.Editor.link.nsColor
                webLink = link
            case .internalLink(let link):
                color = BeamColor.Editor.bidirectionalLink.nsColor
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
            stringAttributes[.underlineColor] = BeamColor.Editor.linkDecoration.nsColor
            stringAttributes[NSAttributedString.Key.hoverUnderlineColor] = BeamColor.Editor.link.nsColor
        } else if let link = internalLink {
            stringAttributes[.link] = link
            stringAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.underlineColor] = NSColor.clear
            stringAttributes[NSAttributedString.Key.hoverUnderlineColor] = BeamColor.Editor.bidirectionalLink.nsColor
        }

        if strikethrough {
            stringAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            stringAttributes[.strikethroughColor] = BeamColor.Editor.underlineAndStrikethrough.nsColor
        }

        if let source = source {
            stringAttributes[.source] = source
        }

        return stringAttributes
    }

    static func isPositionOnLinkArrow(_ position: Int, in range: BeamText.Range) -> Bool {
        return position == range.end
    }

    func addImageToLink(_ attributedString: NSMutableAttributedString, _ range: BeamText.Range, mouseInteraction: MouseInteraction?) {
        guard attributedString.length > 0 else { return }
        guard range.attributes.contains(where: { attrib -> Bool in attrib.rawValue == BeamText.Attribute.link("").rawValue }) else { return }
        let imageName = "editor-url"
        guard let image = NSImage(named: imageName) else { return }

        var color = BeamColor.Editor.linkDecoration.nsColor
        if let mouseInt = mouseInteraction, mouseInt.type == .hovered, Self.isPositionOnLinkArrow(mouseInt.range.lowerBound, in: range) {
            color = BeamColor.Editor.link.nsColor
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
