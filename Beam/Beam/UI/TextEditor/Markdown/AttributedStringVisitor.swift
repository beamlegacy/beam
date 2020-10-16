//
//  AttributedStringVisitor.swift
//  Beam
//
//  Created by Sebastien Metrot on 14/10/2020.
//

import Foundation
import AppKit

extension String {
    func attributed(_ node: Parser.Node, _ showMD: Bool, _ attribs: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let v = NSMutableAttributedString(string: self)
        v.addAttributes(attribs, range: NSRange(location: 0, length: v.length))

        // swiftlint:disable fallthrough no_fallthrough_only
        switch node.type {
        case .internalLink: fallthrough
        case .link: fallthrough
        case .newLine: fallthrough
        case .text:
            v.addAttribute(.sourcePos, value: NSNumber(value: node.positionInSource), range: v.wholeRange)
        default:
            if showMD {
                v.addAttribute(.sourcePos, value: NSNumber(value: node.positionInSource), range: v.wholeRange)
            }
        }
        // swiftlint:enable fallthrough

        return v
    }
}

class AttributedStringVisitor {
    struct Context {
        var bold = false
        var italic = false
        var link = false
        var color: NSColor?
        var showMD = false
        var quoteLevel = 0
        var headingLevel = 0
    }

    struct Configuration {
        var attribs: [Parser.NodeType: [NSAttributedString.Key: Any]] = [:]

        init() {
//            attribs[.text("")] = [.font: NSFont.systemFont(ofSize: 14, weight: .regular)]
//            attribs[.strong] = [.font: NSFont.systemFont(ofSize: 14, weight: .bold)]
//            attribs[.emphasis] = [.font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 14, weight: .regular), toHaveTrait: .italicFontMask)]
        }
    }

//    private var contextStack: [Context]
//    var context: Context {
//        return contextStack.last!
//    }

    var configuration: Configuration
    private func attribs(for node: Parser.Node, context: Context) -> [NSAttributedString.Key: Any] {
        let h = context.headingLevel != 0 ?
            (14 - context.headingLevel * 4)
            : 0
        let bold = context.bold || h != 0
        var font = NSFont.systemFont(ofSize: CGFloat(14 + h), weight: bold ? .bold : .regular)
        var attr = [NSAttributedString.Key: Any]()

        if context.quoteLevel != 0 {
            attr[.foregroundColor] = NSColor.gray
        }

        if context.link {
            attr[.foregroundColor] = NSColor.linkColor
            attr[.underlineStyle] = NSNumber(value: NSUnderlineStyle.single.rawValue)
        } else if let color = context.color {
            attr[.foregroundColor] = color
        }

        if context.italic || context.quoteLevel != 0 {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        attr[.font] = font

        return attr
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func visitChildren(_ node: Parser.Node) -> NSMutableAttributedString {
        let attributed = "".attributed

        for c in node.children {
            let str = visit(c)
            attributed.append(str)
        }
        return attributed
    }

    var context = Context()
    var contextStack = [Context()]

    func pushContext() {
        contextStack.append(context)
    }

    func popContext() {
        context = contextStack.last!
        _ = contextStack.dropLast()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visit(_ node: Parser.Node) -> NSMutableAttributedString {
        switch node.type {
        case let .text(str):
            if str.isEmpty {
                return visitChildren(node)
            } else {
                return str.attributed(node, context.showMD, attribs(for: node, context: context))
            }

        case .strong:
            pushContext(); defer { popContext() }
            context.bold = true
            return visitChildren(node).addAttributes(attribs(for: node, context: context))
        case .emphasis:
            pushContext(); defer { popContext() }
            context.italic = true
            return visitChildren(node).addAttributes(attribs(for: node, context: context))

        case let .link(link):
            pushContext(); defer { popContext() }
            context.link = true
            let str = visitChildren(node).addAttributes(attribs(for: node, context: context))
            if let url = URL(string: link) {
                str.addAttribute(.link, value: url as NSURL, range: str.wholeRange)
            } else if let url = URL(string: link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!) {
                str.addAttribute(.link, value: url as NSURL, range: str.wholeRange)
            }
            return str

        case let .internalLink(link):
            pushContext(); defer { popContext() }
            context.link = true
            let str = link.attributed.addAttributes(attribs(for: node, context: context))
            str.addAttribute(.link, value: URL(string: link)! as NSURL, range: str.wholeRange)
            return str

        case let .heading(depth):
            pushContext(); defer { popContext() }
            context.headingLevel = depth
            return visitChildren(node).addAttributes(attribs(for: node, context: context))

        case .embed:
            return "<IMG>".attributed

        case let .quote(depth):
            pushContext(); defer { popContext() }
            context.quoteLevel = depth
            return visitChildren(node).addAttributes(attribs(for: node, context: context))

        case .newLine:
            return "\n".attributed
        }
    }
}
