//
//  AttributedStringVisitor.swift
//  Beam
//
//  Created by Sebastien Metrot on 14/10/2020.
//

import Foundation
import AppKit

extension NSAttributedString.Key {
    static let sourcePos = NSAttributedString.Key(rawValue: "beamSourcePos")
    static let heading = NSAttributedString.Key(rawValue: "beamHeading")
}

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

enum LinkType {
    case off
    case bidirectionalLink
    case hyperLink
}

class AttributedStringVisitor {
    struct Context {
        var bold = false
        var italic = false
        var link = LinkType.off
        var color: NSColor?
        var showMD = true
        var quoteLevel = 0
        var headingLevel = 0
    }

    struct Configuration {
        init() {
        }
    }

//    private var contextStack: [Context]
//    var context: Context {
//        return contextStack.last!
//    }

    var cursorPosition: Int = -1
    var anchorPosition: Int = -1
    var configuration: Configuration
    var defaultFontSize = CGFloat(16)

    class func font(_ size: CGFloat? = nil, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: size ?? CGFloat(12), weight: weight)
    }

    func font(for context: Context) -> NSFont {
        let fontSizes = [ defaultFontSize, defaultFontSize + 2, defaultFontSize]
        let bold = context.bold || context.headingLevel != 0
        var f = Self.font(CGFloat(fontSizes[context.headingLevel]), weight: bold ? .bold : .regular)
        if context.italic || context.quoteLevel != 0 {
            f = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
        }

        return f
    }

    private func attribs(for node: Parser.Node, context: Context) -> [NSAttributedString.Key: Any] {
        var attr = [NSAttributedString.Key: Any]()

        var foregroundColor = NSColor(named: "EditorTextColor")!

        if context.quoteLevel != 0 {
            foregroundColor = .gray
        }

        if context.link != .off {
            switch context.link {
            case .bidirectionalLink:
                foregroundColor = NSColor(named: "EditorBidirectionalLinkColor")!
            case .hyperLink:
                foregroundColor = NSColor(named: "EditorLinkColor")!
            default:
                break
            }
        } else if let color = context.color {
            foregroundColor = color
        }

        if context.headingLevel == 1 {
            attr[.baselineOffset] = -10
        } else if context.headingLevel == 2 {
            attr[.baselineOffset] = -15
        }

        attr[.foregroundColor] = foregroundColor
        attr[.font] = font(for: context)

        return attr
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    enum Order {
        case pre
        case post
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visitChildren(_ node: Parser.Node, _ applyAttributes: Bool, order: Order = .pre) -> NSMutableAttributedString {
        let decorate: Bool = {
            guard context.showMD else { return false }
            switch node.type {
            case .text:
                return false
            case .newLine:
                return false
            default:
                return true
            }
        }()
        var attributed = "".attributed

        for c in node.children {
            let str = visit(c)
            attributed.append(str)
        }

        if applyAttributes && order == .pre {
            attributed = attributed.replaceAttributes(attribs(for: node, context: context))
        }

        let f = font(for: context)
        var heading = 0
        switch node.type {
        case .embed:
            attributed.insert(node.prefix(decorate, f), at: 0)
        case .emphasis:
            attributed.append(node.suffix(decorate, f))
            attributed.insert(node.prefix(decorate, f), at: 0)
        case .heading(let h):
            attributed.insert(node.prefix(decorate, f), at: 0)
            heading = h
        case .internalLink:
            attributed.insert(node.prefix(decorate, f), at: 0)
            attributed.append(node.suffix(decorate, f))
        case .link:
            attributed.insert(node.prefix(decorate, f), at: 0)
            attributed.append(node.suffix(decorate, f))
        case .quote:
            attributed.insert(node.prefix(decorate, f), at: 0)
        case .strong:
            attributed.insert(node.prefix(decorate, f), at: 0)
            attributed.append(node.suffix(decorate, f))
        case .newLine:
            break
        case .text:
            break
        }

        if applyAttributes && order == .post {
            attributed = attributed.replaceAttributes(attribs(for: node, context: context))
        }

        if heading != 0 {
            attributed.addAttribute(.heading, value: NSNumber(value: heading), range: attributed.wholeRange)
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
        let showMD = context.showMD
        defer {
            context.showMD = showMD
        }

        context.showMD = node.contains(position: cursorPosition) || node.contains(position: anchorPosition)
        switch node.type {
        case let .text(str):
            if str.isEmpty {
                return visitChildren(node, false)
            } else {
                return str.attributed(node, context.showMD, attribs(for: node, context: context))
            }

        case .strong:
            pushContext(); defer { popContext() }
            context.bold = true
            return visitChildren(node, true)
        case .emphasis:
            pushContext(); defer { popContext() }
            context.italic = true
            return visitChildren(node, true)

        case let .link(link):
            pushContext(); defer { popContext() }
            context.link = .hyperLink
            let str = visitChildren(node, false)
            if let url = URL(string: link) {
                str.addAttribute(.link, value: url as NSURL, range: str.wholeRange)
            } else if let url = URL(string: link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!) {
                str.addAttribute(.link, value: url as NSURL, range: str.wholeRange)
            }
            return str

        case let .internalLink(link):
            pushContext(); defer { popContext() }
            context.link = .bidirectionalLink
            let attributedLink = link.attributed(node, context.showMD, attribs(for: node, context: context))
            let f = font(for: context)
            attributedLink.addAttribute(.link, value: link, range: attributedLink.wholeRange)
            attributedLink.insert(node.prefix(context.showMD, f), at: 0)
            attributedLink.append(node.suffix(context.showMD, f))
            return attributedLink

        case .embed:
            return "<IMG>".attributed

        case let .heading(depth):
            pushContext(); defer { popContext() }
            context.headingLevel = depth
            return visitChildren(node, true, order: .post)

        case let .quote(depth):
            pushContext(); defer { popContext() }
            context.quoteLevel = depth
            return visitChildren(node, true, order: .post)

        case .newLine:
            return "\n".attributed
        }
    }
}
