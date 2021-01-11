//
//  BeamText+NSAttributedString.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import AppKit

extension BeamText {
    func buildAttributedString(fontSize: CGFloat, cursorPosition: Int, elementKind: ElementKind) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for range in ranges {
            string.append(NSAttributedString(string: range.string, attributes: convert(attributes: range.attributes, fontSize: fontSize, elementKind: elementKind)))
        }
        return string
    }

    private func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private func font(fontSize: CGFloat, strong: Bool, emphasis: Bool, elementKind: ElementKind) -> NSFont {
        var weight = NSFont.Weight.regular
        let headingFirstLevel: CGFloat = 28
        let headingSecondLevel: CGFloat = 22
        var quote = false
        var size = fontSize

        switch elementKind {
        case .bullet:
            break
        case .code:
            break
        case let .heading(level):
            weight += 1
            size = level == 1 ? headingFirstLevel : headingSecondLevel
        case .quote:
            quote = true
        }

        if strong {
            weight += 1
        }

        var f = NSFont.systemFont(ofSize: size, weight: weight)

        if emphasis || quote {
            f = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
        }

        return f
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func convert(attributes: [Attribute], fontSize: CGFloat, elementKind: ElementKind) -> [NSAttributedString.Key: Any] {
        var stringAttributes = [NSAttributedString.Key: Any]()
        var strong = false
        var emphasis = false
        var headingLevel = 0
        var quote = false
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
            case .heading(let level):
                headingLevel = level
            case .quote: //(level, title, source):
//                quoteLevel = level
//                quoteTitle = title
//                quoteSource = source
                quote = true
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
        } else if let link = internalLink {
            stringAttributes[.link] = link
        }

        if headingLevel > 0 {
            stringAttributes[.heading] = NSNumber(value: headingLevel)
        }

        if let source = source {
            stringAttributes[.source] = source
        }

        return stringAttributes
    }
}
