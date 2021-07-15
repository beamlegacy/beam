//
//  BeamTextVisitor.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import BeamCore

class BeamTextVisitor {
    struct Configuration {
        init() {
        }
    }

    var anchorPosition: Int = -1

    init() {
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visitChildren(_ node: Parser.Node) -> BeamText {
        var attributed = BeamText()

        for c in node.children {
            let str = visit(c)
            attributed.append(str)
        }

        return attributed
    }

    var context = [BeamText.Attribute]()
    var contextStack = [[BeamText.Attribute]]()

    func pushContext() {
        contextStack.append(context)
    }

    func popContext() {
        context = contextStack.last!
        contextStack = contextStack.dropLast()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visit(_ node: Parser.Node) -> BeamText {
        switch node.type {
        case let .text(str):
            if str.isEmpty {
                return visitChildren(node)
            } else {
                return BeamText(text: str, attributes: context)
            }

        case .strong:
            pushContext(); defer { popContext() }
            context.append(.strong)
            return visitChildren(node)
        case .emphasis:
            pushContext(); defer { popContext() }
            context.append(.emphasis)
            return visitChildren(node)

        case let .link(link):
            pushContext(); defer { popContext() }
            context.append(.link(link))
            return visitChildren(node)

        case let .internalLink(link):
            pushContext(); defer { popContext() }
            let linkID = BeamNote.idForNoteNamed(link) ?? UUID.null
            context.append(.internalLink(linkID))
            return BeamText(text: link, attributes: context)

        case .embed:
            return BeamText() // ???

        case .heading:
            pushContext(); defer { popContext() }
//            context.append(.heading(depth))
            return visitChildren(node)

        case .quote:
            pushContext(); defer { popContext() }
//            context.append(.quote(depth, "", ""))
            return visitChildren(node)

        case .check:
            pushContext(); defer { popContext() }
//            context.append(.check(checked))
            return visitChildren(node)
        case .newLine:
            return BeamText(text: "\n")
        }
    }
}
