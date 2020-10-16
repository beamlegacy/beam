//
//  Parser.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/10/2020.
//

import Foundation

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

    class Node {
        var type: NodeType
        var positionInSource: Int

        var children: [Node] = []

        init(type: NodeType, _ positionInSource: Int) {
            self.type = type
            self.positionInSource = positionInSource
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
//            print("next token \(token)" )
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
            context.nextToken()
            return
        }
        let newNode = Node(type: .text(context.token.string), context.token.start)
        context.append(node: newNode)
        context.nextToken()
    }

    private func appendTextNode(_ context: ASTContext, _ string: String, _ start: Int) {
        if let base = context.node.children.last, let str = extractTextFromType(base.type), base.positionInSource + str.count == start {
            // Concatenate the text...
            base.type = .text(str + string)
            return
        }
        let newNode = Node(type: .text(string), start)
        context.append(node: newNode)
    }

    private func parseTokensAsText(_ context: ASTContext, _ tokens: [Lexer.Token]) {
        for token in tokens {
            let newNode = Node(type: .text(token.string), token.start)
            context.append(node: newNode)
        }
    }

    private func parseStrong(_ context: ASTContext) {
        let startToken = context.token
        context.nextToken()
        let newNode = Node(type: .strong, startToken.start)
        context.append(node: newNode)
        context.push(node: newNode); defer { context.pop() }
        while !context.isDone
                && context.token.type != .Strong
                && startToken.string != context.token.string {
            parseTokenAsText(context)
        }

        if context.isDone {
            return
        }
        context.nextToken() // Skip the end of the emphasis
    }

    private func parseEmphasis(_ context: ASTContext) {
        let startToken = context.token
        context.nextToken()
        let newNode = Node(type: .emphasis, startToken.start)
        context.append(node: newNode)
        context.push(node: newNode); defer { context.pop() }
        while !context.isDone
                && context.token.type != .Emphasis
                && startToken.string != context.token.string {
            parseTokenAsText(context)
        }

        if context.isDone {
            return
        }
        context.nextToken() // Skip the end of the emphasis
    }

    private func parseLink(_ context: ASTContext) {
        let linkNode = Node(type: .link(""), context.token.start)
        context.append(node: linkNode)
        context.push(node: linkNode); defer { context.pop() }
        context.nextToken()
        while context.token.type != .CloseSBracket && !context.isDone {
            parseToken(context)
        }

        if context.isDone {
            return
        }

        let openParent = context.nextToken()
        guard openParent.type == .OpenParent else { return }

        context.nextToken() // skip the open parenthesis
        var url = ""
        while context.token.type != .CloseParent && !context.isDone {
            url += context.token.string
            context.nextToken()
//            parseToken(context)
        }

        if context.isDone {
            return
        }

        context.node.type = .link(url)
        context.nextToken()
    }

    private func parseInternalLink(_ context: ASTContext) {
        let linkNode = Node(type: .internalLink(""), context.token.start)
        context.append(node: linkNode)
        context.push(node: linkNode); defer { context.pop() }
        context.nextToken()
        while context.token.type != .LinkEnd && !context.isDone {
            parseTokenAsText(context)
        }

        if context.isDone {
            return
        }

        var url = ""
        for c in linkNode.children {
            switch c.type {
            case let .text(str):
                url += str
            default:
                assert(false) // We should never reach here
            }
        }

        context.node.type = .link(url)
        context.nextToken()
    }

    // TODO Factorise this code with parseQuote
    private func parseHeading(_ context: ASTContext) {
        let start = context.token.start
        var level = 1
        context.nextToken()
        while context.token.type == .Hash && level <= 7 {
            level += 1
            context.nextToken()
        }
        if context.token.type != .Blank {
            let string: String = { var str = ""; for _ in 0..<level { str += "#" }; return str }()
            appendTextNode(context, string, start)
            return
        }
        let heading = Node(type: .heading(level), start)
        context.append(node: heading)
        context.push(node: heading); defer { context.pop() }

        // accumulate nodes until the end of the line:
        while context.token.type != .NewLine && !context.isDone {
            parseToken(context)
        }
    }

    private func parseEmbed(_ context: ASTContext) {
        let embedToken = context.token
        context.nextToken()
        guard context.token.type == .OpenSBracket else { parseTokensAsText(context, [embedToken]); return }

        let embed = Node(type: .embed, embedToken.start)
        context.append(node: embed)
        context.push(node: embed); defer { context.pop() }
        parseLink(context)
    }

    private func parseQuote(_ context: ASTContext) {
        let start = context.token.start
        var level = 1
        context.nextToken()
        while context.token.type == .Quote {
            level += 1
            context.nextToken()
        }
        if context.token.type != .Blank {
            let string: String = { var str = ""; for _ in 0..<level { str += ">" }; return str }()
            appendTextNode(context, string, start)
            return
        }
        let heading = Node(type: .quote(level), start)
        context.append(node: heading)
        context.push(node: heading); defer { context.pop() }

        // accumulate nodes until the end of the line:
        while context.token.type != .NewLine && !context.isDone {
            parseToken(context)
        }
    }

    private func parseNewLine(_ context: ASTContext) {
        context.append(node: Node(type: .newLine, context.token.start))
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
