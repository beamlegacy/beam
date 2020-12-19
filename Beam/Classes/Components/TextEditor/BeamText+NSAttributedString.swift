//
//  BeamText+NSAttributedString.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import AppKit

extension BeamText {
    func buildAttributedString(fontSize: CGFloat, cursorPosition: Int) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for range in ranges {
            string.append(NSAttributedString(string: range.string, attributes: convert(attributes: range.attributes, fontSize: fontSize)))
        }
        return string
    }

    private func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private func font(fontSize: CGFloat, strong: Bool, emphasis: Bool, headingLevel: Int, quote: Bool) -> NSFont {
        let headingFirstLevel: CGFloat = 28
        let headingSecondLevel: CGFloat = 22

        let fontSizes = [fontSize, headingFirstLevel, headingSecondLevel]
        let bold = strong || headingLevel != 0
        var f = NSFont.systemFont(ofSize: fontSizes[headingLevel], weight: bold ? .medium : .regular)

        if emphasis || quote {
            f = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
        }

        return f
    }

    private func convert(attributes: [Attribute], fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        var stringAttributes = [NSAttributedString.Key: Any]()
        var strong = false
        var emphasis = false
        var headingLevel = 0
        var quote = false
        var color = NSColor.editorTextColor
        var quoteLevel: Int
        var quoteTitle: String?
        var quoteSource: String?
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
            case .heading(let level):
                headingLevel = level
            case let .quote(level, title, source):
                quoteLevel = level
                quoteTitle = title
                quoteSource = source
                quote = true
            }
        }

        stringAttributes[.font] = font(fontSize: fontSize, strong: strong, emphasis: emphasis, headingLevel: headingLevel, quote: quote)
        stringAttributes[.foregroundColor] = color
        if let link = webLink {
            if let url = URL(string: link) {
                stringAttributes[.link] = url as NSURL
            } else if let url = URL(string: link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!) {
                stringAttributes[.link] = url as NSURL
            }
        } else if let link = internalLink {
            stringAttributes[.link] = link
        }

        if headingLevel > 0 {
            stringAttributes[.heading] = NSNumber(value: headingLevel)
        }

        if let source = source {
            stringAttributes[.source] = source
        }

        if let source = source {
            stringAttributes[.source] = source
        }

        return stringAttributes
    }
}
