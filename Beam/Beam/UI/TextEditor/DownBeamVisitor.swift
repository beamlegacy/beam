//
//  DownBeamVisitor.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/10/2020.
//
// swiftlint:disable file_length

import Foundation
import Down
import libcmark
import AppKit

extension NSAttributedString.Key {
    static let sourcePos = NSAttributedString.Key(rawValue: "beamSourcePos")
}

class BeamListItemPrefixGenerator {

    private var prefixes: IndexingIterator<[String]>

    convenience init(list: List) {
        self.init(listType: list.listType, numberOfItems: list.numberOfItems)
    }

    init(listType: List.ListType, numberOfItems: Int) {
        switch listType {
        case .bullet:
            prefixes = [String](repeating: "•", count: numberOfItems)
                .makeIterator()

        case .ordered(let start):
            prefixes = (start..<(start + numberOfItems))
                .map { "\($0)." }
                .makeIterator()
        }
    }

    func next() -> String? {
        prefixes.next()
    }
}

extension DownAttributedStringRenderable {

    /// Generates an `NSAttributedString` from the `markdownString` property
    ///
    /// **Note:** The attributed string is constructed directly by traversing the abstract syntax tree. It is
    /// much faster than the `toAttributedString(options: stylesheet)` method and it can be also be
    /// rendered in a background thread.
    ///
    /// - Parameters:
    ///   - options: `DownOptions` to modify parsing or rendering
    ///   - styler: a class/struct conforming to `Styler` to use when rendering the various elements of the attributed string
    /// - Returns: An `NSAttributedString`
    /// - Throws: `DownErrors` depending on the scenario
    public func toAttributedStringBeam(sourceString: String, _ options: DownOptions = .default, styler: Styler, cursorPosition: Int) throws -> NSAttributedString {
//        print("toAttributedStringBeam...")
        let document = try self.toDocument(options)
        let visitor = BeamAttributedStringVisitor(sourceString: sourceString, styler: styler, options: options, cursorPosition: cursorPosition)
        return document.accept(visitor)
    }

    public func toAttributedStringBeam(visitor: BeamAttributedStringVisitor, _ options: DownOptions = .default) throws -> NSAttributedString {
//        print("toAttributedStringBeam...")
        let document = try self.toDocument(options)
        return document.accept(visitor)
    }
}

public class BeamAttributedStringVisitor {

    private let styler: Styler
    private let options: DownOptions
    private var listPrefixGenerators = [BeamListItemPrefixGenerator]()

    private var sourceString: String
    private var sourceLines = [Range<Int>]()

    var contextualSyntax = true
    var showStyle = false
    var showStyleStack = [Bool]()
    var cursorPosition: Int

    public struct LineInfo {
        var source_start: Int = 0
        var source_end: Int = 0
        var source_length: Int { source_end - source_start }

        var visible_start: Int = 0
        var visible_end: Int = 0

        init() {
        }

        init(_ node: BaseNode, _ string: NSAttributedString, _ sourceLines: [Range<Int>]) {
            let start_line = Int(node.cmarkNode.pointee.start_line) - 1
            let start_column = min(sourceLines.first!.upperBound, Int(node.cmarkNode.pointee.start_column) - 1)
            let end_line = Int(node.cmarkNode.pointee.end_line) - 1
            let end_column = min(sourceLines.last!.upperBound, Int(node.cmarkNode.pointee.end_column))

            source_start = sourceLines[start_line].lowerBound + start_column
            source_end = sourceLines[end_line].lowerBound + end_column

            visible_start = 0
            visible_end = string.string.count
        }

        mutating func rebase(start: Int) {
            source_start += start
            source_end += start
        }
    }

    /// Creates a new instance with the given styler and options.
    ///
    /// - parameters:
    ///     - styler: used to style the markdown elements.
    ///     - options: may be used to modify rendering.
    public init(sourceString: String, styler: Styler, options: DownOptions = .default, cursorPosition: Int) {
        self.sourceString = sourceString
        self.cursorPosition = cursorPosition
        let lines = sourceString.split(omittingEmptySubsequences: false) { $0.isNewline }
        for l in lines {
            sourceLines.append(sourceString.position(at: l.startIndex) ..< sourceString.position(at: l.endIndex))
        }

        self.styler = styler
        self.options = options
    }
}

extension BeamAttributedStringVisitor: Visitor {
    public typealias Result = NSMutableAttributedString

    func registerNode(_ node: BaseNode, _ string: NSAttributedString) {
    }

    func decorate(_ node: BaseNode, _ string: NSMutableAttributedString) -> NSMutableAttributedString {
        let info = LineInfo(node, "".attributed, sourceLines)
        let count = string.length

        if node.children.isEmpty {
            let pos = info.source_start as NSNumber
            string.addAttribute(.sourcePos, value: pos, range: NSRange(location: 0, length: count))
            return string
        }

        guard showStyle else { return string }

        let preAttribs = string.attributes(at: 0, effectiveRange: nil)
        let postAttribs = string.attributes(at: count - 1, effectiveRange: nil)

        guard let firstChild = node.children.first as? BaseNode else { return string }
        guard let lastChild = node.children.last as? BaseNode else { return string }

        let firstInfo = LineInfo(firstChild, "".attributed, sourceLines)
        let lastInfo = LineInfo(lastChild, "".attributed, sourceLines)

        let prefix = sourceString.substring(range: info.source_start..<firstInfo.source_start).attributed
        let postfix = sourceString.substring(range: lastInfo.source_end..<info.source_end).attributed

        prefix.addAttributes(preAttribs, range: NSRange(location: 0, length: prefix.length))
        prefix.addAttribute(.sourcePos, value: info.source_start as NSNumber, range: NSRange(location: 0, length: prefix.length))
        postfix.addAttributes(postAttribs, range: NSRange(location: 0, length: postfix.length))
        postfix.addAttribute(.sourcePos, value: lastInfo.source_end as NSNumber, range: NSRange(location: 0, length: postfix.length))

        string.insert(postfix, at: count)
        string.insert(prefix, at: 0)

        return string
    }

    func update(_ node: BaseNode) {
        guard contextualSyntax else { return }
        showStyleStack.append(showStyle)
        let info = LineInfo(node, "".attributed, sourceLines)
        showStyle = cursorPosition >= info.source_start && cursorPosition <= info.source_end
    }

    func leave(_ node: BaseNode) {
        guard contextualSyntax else { return }
        showStyle = showStyleStack.popLast()!
    }

    public func visit(document node: Document) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = decorate(node, visitChildren(of: node).joined)
        styler.style(document: s)
        registerNode(node, s)
        return s
    }

    public func visit(blockQuote node: BlockQuote) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        if node.hasSuccessor { s.append(.paragraphSeparator) }
        let str = decorate(node, s)
        styler.style(blockQuote: str, nestDepth: node.nestDepth)
        registerNode(node, str)
        return str
    }

    public func visit(list node: List) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        listPrefixGenerators.append(BeamListItemPrefixGenerator(list: node))
        defer { listPrefixGenerators.removeLast() }

        let items = visitChildren(of: node)

        let s = items.joined
        if node.hasSuccessor { s.append(.paragraphSeparator) }
        let str = decorate(node, s)
        styler.style(list: str, nestDepth: node.nestDepth)
        registerNode(node, str)
        return str
    }

    public func visit(item node: Item) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined

        let prefix = listPrefixGenerators.last?.next() ?? "•"
        let attributedPrefix = "\(prefix)\t".attributed
        styler.style(listItemPrefix: attributedPrefix)
        s.insert(attributedPrefix, at: 0)

        if node.hasSuccessor { s.append(.paragraphSeparator) }

        let str = decorate(node, s)
        styler.style(item: str, prefixLength: (prefix as NSString).length)
        registerNode(node, str)
        return str
    }

    public func visit(codeBlock node: CodeBlock) -> NSMutableAttributedString {
        guard let literal = node.literal else { return .empty }
        update(node); defer { leave(node) }
        let s = literal.replacingNewlinesWithLineSeparators().attributed
        if node.hasSuccessor { s.append(.paragraphSeparator) }
        let str = decorate(node, s)
        styler.style(codeBlock: str, fenceInfo: node.fenceInfo)
        registerNode(node, str)
        return str
    }

    public func visit(htmlBlock node: HtmlBlock) -> NSMutableAttributedString {
        guard let literal = node.literal else { return .empty }
        update(node); defer { leave(node) }
        let s = literal.replacingNewlinesWithLineSeparators().attributed
        if node.hasSuccessor { s.append(.paragraphSeparator) }
        let str = decorate(node, s)
        styler.style(htmlBlock: str)
        registerNode(node, str)
        return str
    }

    public func visit(customBlock node: CustomBlock) -> NSMutableAttributedString {
        guard let s = node.literal?.attributed else { return .empty }
        update(node); defer { leave(node) }
        let str = decorate(node, s)
        styler.style(customBlock: str)
        registerNode(node, str)
        return str
    }

    public func visit(paragraph node: Paragraph) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        if node.hasSuccessor { s.append(.paragraphSeparator) }
        let str = decorate(node, s)
        styler.style(paragraph: str)
        registerNode(node, str)
        return str
    }

    public func visit(heading node: Heading) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        if node.hasSuccessor { s.append(.paragraphSeparator) }
        let str = decorate(node, s)
        styler.style(heading: str, level: node.headingLevel)
        registerNode(node, str)
        return str
    }

    public func visit(thematicBreak node: ThematicBreak) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = "\(String.zeroWidthSpace)\n".attributed
        let str = decorate(node, s)
        styler.style(thematicBreak: str)
        registerNode(node, str)
        return str
    }

    public func visit(text node: Text) -> NSMutableAttributedString {
        guard let literal = node.literal else { return .empty }
        let s = literal.attributed
        update(node); defer { leave(node) }
        let str = decorate(node, s)
        let attribs = str.positionAttribs
        styler.style(text: str)
        str.positionAttribs = attribs
        let ranges = literal.capturedRanges(withRegex: "\\[\\[([\\w+\\s*]+\\w)\\]\\]")

        for range in ranges {
            let value = literal.substring(range: range).attributed
            styler.style(link: value, title: value.string, url: value.string)
            let attributes = value.attributes(at: 0, effectiveRange: nil)
//            print("found link \(value) / \(attributes)")
            s.addAttributes(attributes, range: NSRange(location: range.lowerBound, length: range.count))
        }

        registerNode(node, str)
        return str
    }

    public func visit(softBreak node: SoftBreak) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = (options.contains(.hardBreaks) ? String.lineSeparator : " ").attributed
        let str = decorate(node, s)
        styler.style(softBreak: str)
        registerNode(node, str)
        return str
    }

    public func visit(lineBreak node: LineBreak) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = String.lineSeparator.attributed
        let str = decorate(node, s)
        styler.style(lineBreak: str)
        registerNode(node, str)
        return str
    }

    public func visit(code node: Code) -> NSMutableAttributedString {
        guard let s = node.literal?.attributed else { return .empty }
        update(node); defer { leave(node) }
        let str = decorate(node, s)
        styler.style(code: str)
        registerNode(node, str)
        return str
    }

    public func visit(htmlInline node: HtmlInline) -> NSMutableAttributedString {
        guard let s = node.literal?.attributed else { return .empty }
        update(node); defer { leave(node) }
        let str = decorate(node, s)
        styler.style(htmlInline: str)
        registerNode(node, str)
        return str
    }

    public func visit(customInline node: CustomInline) -> NSMutableAttributedString {
        guard let s = node.literal?.attributed else { return .empty }
        update(node); defer { leave(node) }
        let str = decorate(node, s)
        styler.style(customInline: str)
        registerNode(node, str)
        return str
    }

    public func visit(emphasis node: Emphasis) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        let str = decorate(node, s)
        styler.style(emphasis: str)
        registerNode(node, str)
        return str
    }

    public func visit(strong node: Strong) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        let str = decorate(node, s)
        styler.style(strong: str)
        registerNode(node, str)
        return str
    }

    public func visit(link node: Link) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        let str = decorate(node, s)
        styler.style(link: str, title: node.title, url: node.url)
        registerNode(node, str)
        return str
    }

    public func visit(image node: Image) -> NSMutableAttributedString {
        update(node); defer { leave(node) }
        let s = visitChildren(of: node).joined
        let str = decorate(node, s)
        styler.style(image: str, title: node.title, url: node.url)
        registerNode(node, str)
        return str
    }
}

// MARK: - Helper extensions

private extension Sequence where Iterator.Element == NSMutableAttributedString {

    var joined: NSMutableAttributedString {
        return reduce(into: NSMutableAttributedString()) { $0.append($1) }
    }
}
