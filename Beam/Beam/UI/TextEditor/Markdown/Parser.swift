//
//  Parser.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/10/2020.
//
// swiftlint:disable file_length

import Foundation
import AppKit

extension Lexer.Token {
    var attributedString: NSMutableAttributedString {
        let str = string.attributed
        str.addAttribute(.sourcePos, value: start as NSNumber, range: str.wholeRange)
        return str
    }
}

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
    }

    enum DecorationType: Equatable {
        case prefix
        case suffix
        case infix
    }

    class Node {
        var type: NodeType
        var positionInSource: Int
        var length: Int

        var children: [Node] = []

        var decorations = [DecorationType: Lexer.Token]()
        func decoration(_ decorationType: DecorationType, _ decorate: Bool) -> NSMutableAttributedString {
            if !decorate { return "".attributed }
            let deco = decorations[decorationType]!
            let str = deco.attributedString
            if !decorate {
                str.replaceCharacters(in: str.wholeRange, with: String.zeroWidthSpace)
            }
            str.addAttributes([NSAttributedString.Key.foregroundColor: NSColor(named: "EditorSyntaxColor")!], range: str.wholeRange)

            return str
        }
        func prefix(_ decorate: Bool) -> NSMutableAttributedString {
            return decoration(.prefix, decorate)
        }
        func infix(_ decorate: Bool) -> NSMutableAttributedString {
            return decoration(.infix, decorate)
        }
        func suffix(_ decorate: Bool) -> NSMutableAttributedString {
            return decoration(.suffix, decorate)
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
            let tabs: String = { var t = ""; for _ in 0..<depth { t += "\t" }; return t }()

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
            let start: Int = {
                if let prefix = decorations[.prefix] {
                    return prefix.start
                }
                return positionInSource
            }()
            let end: Int = {
                if let suffix = decorations[.suffix] {
                    return suffix.start + suffix.string.count
                }
                return positionInSource + length
            }()
            return position >= start && position <= end
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

        func push(node: Node) {
            nodeStack.append(node)
        }

        func append(node: Node) {
            self.node.children.append(node)
        }

        @discardableResult func pop() -> Node {
            return nodeStack.popLast()!
        }

        @discardableResult func nextToken() -> Lexer.Token {
            isDone = lexer.isFinished
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

    // swiftlint:disable:next function_body_length
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
        let startToken = context.token
        var level = 1
        context.nextToken()
        while context.token.type == tokenType, level < limit ?? 1000 {
            level += 1
            context.nextToken()
        }
        var prefixString: String = ""
        if context.token.type != .Blank {
            appendTextNode(context, startToken.string, startToken.start)
            return
        }
        let heading = Node(type: nodeType(level), startToken.start)
        prefixString.append(context.token.string)
        var prefix = Lexer.Token(type: .Text, string: prefixString)
        prefix.start = startToken.start
        heading.decorations[.prefix] = prefix
        heading.length = context.token.end - heading.positionInSource

        context.append(node: heading)
        context.push(node: heading); defer { context.pop() }

        // accumulate nodes until the end of the line:
        while context.token.type != .NewLine && !context.isDone {
            parseToken(context)
        }
    }

    private func parseHeading(_ context: ASTContext) {
        parseLineStarter(context, tokenType: .Hash, limit: 7) { level in
            return .heading(level)
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

    //swiftlint:disable:next cyclomatic_complexity
    private func parseToken(_ context: ASTContext) {
        let token = context.token
        switch token.type {
        case .Text:
            parseTokenAsText(context)

        case .Blank:
            parseTokenAsText(context)

        case .Strong:
            parseStrong(context)

        case .Emphasis:
            parseEmphasis(context)

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
                context.node.children.append(Node(type: .text(exclamation.string), exclamation.start))
            }

        case .Quote:
            if context.atStartOfLine {
                parseQuote(context)
            } else {
                parseTokenAsText(context)
            }

        case .NewLine:
            parseTokenAsText(context)

        default:
            parseTokenAsText(context)
        }
    }

    func parseAST() -> Node {
        let root = Node(type: .text(""), 0)
        let context = ASTContext(node: root, lexer: lexer)

        context.nextToken()
        while !context.isDone {
            parseToken(context)
        }
        return root
    }
}
