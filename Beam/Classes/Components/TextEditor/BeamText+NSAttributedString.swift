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
            string.append(NSAttributedString(string: range.string, attributes: convert(attributes: range.attributes, fontSize: fontSize, elementKind: elementKind)))
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
        }

        if emphasis || quote {
            guard let selfFont = font else { return NSFont.systemFont(ofSize: fontSize) }
            font = NSFontManager.shared.convert(selfFont, toHaveTrait: .italicFontMask)
        }

        guard let selfFont = font else { return NSFont.systemFont(ofSize: fontSize) }

        return selfFont
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
}
