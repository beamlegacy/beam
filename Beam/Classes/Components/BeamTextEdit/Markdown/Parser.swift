//
//  Parser.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/10/2020.
//

import Foundation
import AppKit
import BeamCore

class Parser {
    enum NodeType: Equatable, Hashable {
        case text(String)
        case strong
        case emphasis
        case link(String)
        case internalLink(String)
        case heading(Int)
        case embed
        case quote(Int)
        case newLine
        case check(Bool)

        var asInt: Int {
            switch self {
            case .text: return 0
            case .strong: return 1
            case .emphasis: return 2
            case .link: return 3
            case .internalLink: return 4
            case .heading: return 5
            case .embed: return 6
            case .quote: return 7
            case .newLine: return 8
            case .check: return 9
            }
        }
    }

    enum DecorationType: Equatable {
        case prefix
        case suffix
        case infix
    }

    class Node: Codable {
        var type: NodeType
        var positionInSource: Int
        var length: Int

        var children: [Node] = []
        var parent: Node?

        var description: String {
            return "Parser.Node[\(type)] (\(start) -> \(end)) \(children.count) children"
        }

        var end: Int {
            return decorations[.suffix]?.end ?? positionInSource + length
        }

        var start: Int {
            return decorations[.prefix]?.start ?? positionInSource
        }

        var decorations = [DecorationType: Lexer.Token]()
        func decoration(_ decorationType: DecorationType, _ decorate: Bool, _ font: NSFont) -> NSMutableAttributedString {
            guard decorate else { return "".attributed }
            let deco = decorations[decorationType]!
            let str = NSMutableAttributedString(string: deco.string)
            str.addAttributes([NSAttributedString.Key.foregroundColor: BeamColor.Editor.syntax.nsColor], range: str.wholeRange)
            str.addAttribute(.font, value: font, range: str.wholeRange)

            return str
        }
        func prefix(_ decorate: Bool, _ font: NSFont) -> NSMutableAttributedString {
            return decoration(.prefix, decorate, font)
        }
        func infix(_ decorate: Bool, _ font: NSFont) -> NSMutableAttributedString {
            return decoration(.infix, decorate, font)
        }
        func suffix(_ decorate: Bool, _ font: NSFont) -> NSMutableAttributedString {
            return decoration(.suffix, decorate, font)
        }

        enum CodingKeys: String, CodingKey {
            case type
            case position
            case text
            case link
            case level
            case value
            case children
            case prefix
            case suffix
            case infix
        }

        required public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            length = 0

            let typeIndex = try container.decode(Int.self, forKey: .type)
            switch typeIndex {
            case NodeType.text("").asInt:
                let t = try container.decode(String.self, forKey: .text)
                type = .text(t)
                length = t.count
            case NodeType.strong.asInt:
                type = .strong
            case NodeType.emphasis.asInt:
                type = .emphasis
            case NodeType.link("").asInt:
                type = .link(try container.decode(String.self, forKey: .link))
            case NodeType.internalLink("").asInt:
                type = .internalLink(try container.decode(String.self, forKey: .link))
            case NodeType.heading(0).asInt:
                type = .heading(try container.decode(Int.self, forKey: .level))
            case NodeType.embed.asInt:
                type = .embed
            case NodeType.quote(0).asInt:
                type = .quote(try container.decode(Int.self, forKey: .level))
            case NodeType.newLine.asInt:
                type = .newLine
            case NodeType.check(false).asInt:
                type = .check(try container.decode(Bool.self, forKey: .value))

            default:
                fatalError("Unexpected Parser.NodeType \(typeIndex)")
            }

            positionInSource = try container.decode(Int.self, forKey: .position)

            if container.contains(.children) {
                children = try container.decode([Node].self, forKey: .children)
            }

            if container.contains(.prefix) { decorations[.prefix] = try container.decode(Lexer.Token.self, forKey: .prefix) }
            if container.contains(.infix) { decorations[.infix] = try container.decode(Lexer.Token.self, forKey: .infix) }
            if container.contains(.suffix) { decorations[.suffix] = try container.decode(Lexer.Token.self, forKey: .suffix) }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(type.asInt, forKey: .type)

            switch type {
            case let .text(string):
                try container.encode(string, forKey: .text)
            case let .link(link):
                try container.encode(link, forKey: .link)
            case let .internalLink(link):
                try container.encode(link, forKey: .link)
            case let .heading(level):
                try container.encode(level, forKey: .level)
            case let .quote(level):
                try container.encode(level, forKey: .level)
            case let .check(value):
                try container.encode(value, forKey: .value)

            default:
                break
            }

            try container.encode(positionInSource, forKey: .position)
            if !children.isEmpty {
                try container.encode(children, forKey: .children)
            }

            try encodeDecorations(to: encoder)
        }

        private func encodeDecorations(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let value = decorations[.prefix] { try container.encode(value, forKey: .prefix) }
            if let value = decorations[.infix] { try container.encode(value, forKey: .infix) }
            if let value = decorations[.suffix] { try container.encode(value, forKey: .suffix) }
        }

        init(type: NodeType, _ positionInSource: Int) {
            self.type = type
            self.positionInSource = positionInSource
            self.length = 0
        }

        var treeString: String {
            return buildTreeString(depth: 0)
        }

        private func buildTreeString(depth: Int) -> String {
            let tabs: String = { var t = ""; for _ in 0..<depth { t += "    " }; return t }()

            var val = tabs + "Node[\(type)]\n"
            for c in children {
                val += c.buildTreeString(depth: depth + 1)
            }
            return val
        }

        /// Return the child that is the last in the tree of children of self
        func lastNode() -> Node {
            if let lastChild = children.last {
                return lastChild.lastNode()
            }
            return self
        }

        func contains(position: Int) -> Bool {
            guard position != -1 else { return false }
            return position >= start && position <= end
        }

        func nodeContainingPosition(_ position: Int) -> Node? {
            guard parent == nil || (positionInSource <= position && position <= positionInSource + length) else { return nil }

            for c in children {
                if let node = c.nodeContainingPosition(position) {
                    return node
                }
            }

            return self
        }

        var enclosingSyntaxNode: Node? {
            guard let p = parent else { return self }
            switch p.type {
            case .text:
                return self
            case .strong:
                return p.enclosingSyntaxNode
            case .emphasis:
                return p.enclosingSyntaxNode
            case .link:
                return p.enclosingSyntaxNode
            case .internalLink:
                return p.enclosingSyntaxNode
            case .heading:
                return p.enclosingSyntaxNode
            case .embed:
                return p.enclosingSyntaxNode
            case .quote:
                return p.enclosingSyntaxNode
            case .newLine:
                return self
            case .check:
                return p.enclosingSyntaxNode
            }
        }
    }

    var lexer: Lexer

    init(inputString: String) {
        lexer = Lexer(inputString: inputString)
    }

    class ASTContext {
        private var nodeStack = [Node]()
        private var lexer: Lexer
        var node: Node {
            nodeStack.last!
        }
        var index: Int = 0

        var token: Lexer.Token
        var isDone = false
        var atStartOfLine = true
        var previousType: Lexer.TokenType = .Blank

        func push(node: Node) {
            nodeStack.append(node)
        }

        func append(node: Node) {
            node.parent = self.node
            self.node.children.append(node)
        }

        @discardableResult func pop() -> Node {
            return nodeStack.popLast()!
        }

        @discardableResult func nextToken() -> Lexer.Token {
            isDone = lexer.isFinished
            previousType = token.type
            token = lexer.nextToken()
            atStartOfLine = token.column == 0
            return token
        }

        init(node: Node, lexer: Lexer) {
            self.nodeStack.append(node)
            self.lexer = lexer
            self.token = lexer.token
        }
    }

    private func extractTextFromType(_ t: NodeType) -> String? {
        switch t {
        case let .text(str):
            return str
        default:
            return nil
        }
    }

    private func parseTokenAsText(_ context: ASTContext) {
        if let base = context.node.children.last, let str = extractTextFromType(base.type), base.positionInSource + str.count == context.token.start {
            // Concatenate the text...
            base.type = .text(str + context.token.string)
            base.length += context.token.string.count
            context.nextToken()
            return
        }
        let newNode = Node(type: .text(context.token.string), context.token.start)
        newNode.length = context.token.string.count
        context.append(node: newNode)
        context.nextToken()
    }

    private func appendTextNode(_ context: ASTContext, _ string: String, _ start: Int) {
        if let base = context.node.children.last, let str = extractTextFromType(base.type), base.positionInSource + str.count == start {
            // Concatenate the text...
            base.type = .text(str + string)
            base.length += string.count
            return
        }
        let newNode = Node(type: .text(string), start)
        newNode.length = string.count
        context.append(node: newNode)
    }

    private func parseTokensAsText(_ context: ASTContext, _ tokens: [Lexer.Token]) {
        for token in tokens {
            let newNode = Node(type: .text(token.string), token.start)
            newNode.length = token.string.count
            context.append(node: newNode)
        }
    }

    private func parseCouple(_ context: ASTContext, type: NodeType) {
        let startToken = context.token
        context.nextToken()
        let newNode = Node(type: type, startToken.start)
        newNode.decorations[.prefix] = startToken
        context.push(node: newNode)
        while !context.isDone
                && startToken.type != context.token.type
                && startToken.string != context.token.string {
            parseToken(context)
        }

        if context.isDone {
            context.pop()
            appendTextNode(context, startToken.string, startToken.start)
            for c in newNode.children {
                context.append(node: c)
            }
            parseTokenAsText(context) // Skip the end of the emphasis
            return
        }

        newNode.decorations[.suffix] = context.token
        newNode.length = context.token.end - newNode.positionInSource
        context.nextToken() // Skip the end of the emphasis
        context.pop()
        context.append(node: newNode)
    }

    private func parseStrong(_ context: ASTContext) {
        parseCouple(context, type: .strong)
    }

    private func parseEmphasis(_ context: ASTContext) {
        parseCouple(context, type: .emphasis)
    }

    private func parseLink(_ context: ASTContext) {
        let linkNode = Node(type: .link(""), context.token.start)
        let prefix = context.token
        linkNode.decorations[.prefix] = prefix
        context.push(node: linkNode)
        context.nextToken()
        while context.token.type != .CloseSBracket && !context.isDone {
            parseToken(context)
        }

        if context.isDone {
            context.pop()
            appendTextNode(context, prefix.string, prefix.start)
            for t in linkNode.children {
                context.append(node: t)
            }
            return
        }

        var infix = context.token

        let openParent = context.nextToken()
        guard openParent.type == .OpenParent else {
            context.pop()
            appendTextNode(context, prefix.string, prefix.start)
            for t in linkNode.children {
                context.append(node: t)
            }
            appendTextNode(context, infix.string, infix.start)
            return
        }

        infix.string += openParent.string

        context.nextToken() // skip the open parenthesis
        var url = ""
        let urlStart = context.token.start
        while context.token.type != .CloseParent && !context.isDone {
            url += context.token.string
            context.nextToken()
        }

        if context.isDone {
            context.pop()
            appendTextNode(context, prefix.string, prefix.start)
            for t in linkNode.children {
                context.append(node: t)
            }
            appendTextNode(context, infix.string, infix.start)
            appendTextNode(context, url, urlStart)
            return
        }

        infix.string += url
        infix.string += context.token.string
        linkNode.decorations[.suffix] = infix
        linkNode.length = context.token.end - linkNode.positionInSource

        linkNode.type = .link(url)
        context.nextToken()
        context.pop()
        context.append(node: linkNode)
    }

    private func parseInternalLink(_ context: ASTContext) {
        let prefix = context.token
        context.nextToken()
        let linkNode = Node(type: .internalLink(""), context.token.start)
        linkNode.decorations[.prefix] = prefix
        context.push(node: linkNode)
        while context.token.type != .LinkEnd && !context.isDone {
            parseTokenAsText(context)
        }

        if context.isDone {
            context.pop()
            appendTextNode(context, prefix.string, prefix.start)
            for t in linkNode.children {
                context.append(node: t)
            }
            return
        }

        linkNode.decorations[.suffix] = context.token
        linkNode.length = context.token.end - linkNode.positionInSource

        var url = ""
        for c in linkNode.children {
            switch c.type {
            case let .text(str):
                url += str
            default:
                assert(false) // We should never reach here
            }
        }

        linkNode.type = .internalLink(url)
        context.pop()
        context.append(node: linkNode)
        context.nextToken()
    }

    private func parseEmbed(_ context: ASTContext) {
        let embedToken = context.token
        context.nextToken()
        guard context.token.type == .OpenSBracket else { parseTokensAsText(context, [embedToken]); return }

        let embed = Node(type: .embed, embedToken.start)
        embed.decorations[.prefix] = embedToken
        embed.length = embedToken.end - embed.positionInSource

        context.append(node: embed)
        context.push(node: embed); defer { context.pop() }
        parseLink(context)
    }

    private func parseLineStarter(_ context: ASTContext, tokenType: Lexer.TokenType, limit: Int?, nodeType: @escaping (Int) -> NodeType) {
        var startToken = context.token
        var level = 1
        context.nextToken()
        while context.token.type == tokenType, level < limit ?? 1000 {
            level += 1
            startToken.string += context.token.string
            context.nextToken()
        }
        if context.token.type != .Blank && context.token.type != .EndOfFile && context.token.type != .NewLine {
            appendTextNode(context, startToken.string, startToken.start)
            return
        }
        if context.token.type == .Blank {
            startToken.string += context.token.string
        }
        let heading = Node(type: nodeType(level), startToken.start)
        heading.decorations[.prefix] = startToken

        context.append(node: heading)
        context.push(node: heading); defer { context.pop() }

        context.nextToken()

        // accumulate nodes until the end of the line:
        while context.token.type != .NewLine && !context.isDone {
            parseToken(context)
        }
        heading.length = context.token.start - heading.positionInSource
    }

    private func parseHeading(_ context: ASTContext) {
        parseLineStarter(context, tokenType: .Hash, limit: 2) { level in
            return .heading(level)
        }
    }

    private func parseCheck(_ context: ASTContext) {
        let startToken = context.token

        context.nextToken()
        let checked = context.token.string == "x"

        context.nextToken()
        guard context.token.type == .CloseSBracket else {
            appendTextNode(context, startToken.string, startToken.start)
            return
        }
        let check = Node(type: .check(checked), startToken.start)
        check.decorations[.prefix] = startToken

        context.append(node: check)
        context.push(node: check); defer { context.pop() }

        context.nextToken()

        // accumulate nodes until the end of the line:
        while context.token.type != .NewLine && !context.isDone {
            parseToken(context)
        }
    }

    private func parseQuote(_ context: ASTContext) {
        parseLineStarter(context, tokenType: .Quote, limit: nil) { level in
            return .quote(level)
        }
    }

    private func parseNewLine(_ context: ASTContext) {
        let node = Node(type: .newLine, context.token.start)
        node.length = context.token.end
        context.append(node: node)
        context.nextToken()
    }

    private func parseToken(_ context: ASTContext) {
        let token = context.token
        switch token.type {
        case .Text:
            parseTokenAsText(context)

        case .Blank:
            parseTokenAsText(context)

        case .Strong:
            if [.EndOfFile, .NewLine, .Blank, .Emphasis, .Strong].contains(context.previousType) {
                parseStrong(context)
            } else {
                parseTokenAsText(context)
            }

        case .Emphasis:
            if [.EndOfFile, .NewLine, .Blank, .Emphasis, .Strong].contains(context.previousType) {
                parseEmphasis(context)
            } else {
                parseTokenAsText(context)
            }

        case .LinkStart:
            parseInternalLink(context)

        case .OpenSBracket:
            parseLink(context)

        case .Hash:
            if context.atStartOfLine {
                parseHeading(context)
            } else {
                parseTokenAsText(context)
            }

        case .ExclamationMark:
            let exclamation = context.token
            context.nextToken()
            if context.token.type == .OpenSBracket {
                context.push(node: Node(type: .embed, exclamation.start)); defer { context.pop() }
                parseLink(context)
            } else {
                let child = Node(type: .text(exclamation.string), exclamation.start)
                child.parent = context.node
                context.node.children.append(child)
            }

        case .Quote:
            if context.atStartOfLine {
                parseQuote(context)
            } else {
                parseTokenAsText(context)
            }

        case .NewLine:
            parseTokenAsText(context)

        case .CheckStart:
            if context.atStartOfLine {
                parseCheck(context)
            } else {
                parseTokenAsText(context)
            }

        default:
            parseTokenAsText(context)
        }
    }

    func parseAST() -> Node {
        let root = Node(type: .text(""), 0)
        let context = ASTContext(node: root, lexer: lexer)

        var index = lexer.input.count
        context.nextToken()
        while !context.isDone && index > 0 {
            parseToken(context)
            index -= 1
        }

        if !context.isDone {
            Logger.shared.logError("Couldn't parse AST: \(lexer.input)", category: .lexer)
        }
        return root
    }
}
