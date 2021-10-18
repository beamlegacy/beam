//
//  Caret.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/04/2021.
//

// Carets have 2 edges (leading = before the character, trailing = after it)
// Some Carets are skipable, they represent virtual characters such as images/icons inserted into the text that have no actual existance in the source string and we must skip over them when moving the caret with the curso keys

import Foundation

public enum WritingDirection {
    case leftToRight
    case rightToLeft
}

public enum CaretPositionInLine {
    case start
    case middle
    case end
}

public struct CaretFilter: OptionSet {
    public let rawValue: Int

    public static let none = CaretFilter([])
    public static let notInSource = CaretFilter(rawValue: 1)
    public static let traillingEdge = CaretFilter(rawValue: 2)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public enum CaretEdge {
    case leading
    case trailing

    var isLeading: Bool { self == .leading }
    var isTrailing: Bool { self == .trailing }
}

public struct Caret: Comparable {
    public static func < (lhs: Caret, rhs: Caret) -> Bool {
        (lhs.indexOnScreen < rhs.indexOnScreen) || ((lhs.indexOnScreen == rhs.indexOnScreen) && (lhs.offset.x < rhs.offset.x))
    }

    public var offset: CGPoint
    /// indexInSource is the index of the character in source string
    public var indexInSource: Int
    public var indexOnScreen: Int
    public var edge: CaretEdge
    public var inSource: Bool
    public var line: Int

    public var direction: WritingDirection = .leftToRight
    public var positionInLine: CaretPositionInLine = .middle

    /// positionInSource is the index in the source string adjusted for edge position (before or after the character)
    public var positionInSource: Int {
        return indexInSource + ((edge == .trailing) ? (inSource ? 1 : 0) : 0)
    }

    /// positionOnScreen is the index in the attributed string adjusted for edge position (before or after the character)
    public var positionOnScreen: Int {
        return indexOnScreen + ((edge == .trailing) ? 1 : 0)
    }

    public static let zero = Caret(offset: .zero, indexInSource: 0, indexOnScreen: 0, edge: .leading, inSource: true, line: 0)

    public var debugDescription: String {
        "Caret src: \(indexInSource) -> \(positionInSource) scrn(\(edge)): \(indexOnScreen) -> \(positionOnScreen) [\(line)] xy\(offset) \(inSource ? "" : "[X]")"
    }

}

public func nextCaret(for index: Int, in carets: [Caret]) -> Int {
    guard index < carets.count - 1 else {
        return carets.count - 1
    }

    var newIndex = index + 1
    let caret = carets[index]
    let offset = caret.offset.x
    let line = caret.line
    while newIndex < carets.count {
        let caret = carets[newIndex]
        if (caret.offset.x > offset && (caret.edge.isLeading || caret.positionInLine == .end)) || caret.line != line {
            return newIndex
        }

        newIndex += 1
    }

    return newIndex
}

public func previousCaret(for index: Int, in carets: [Caret]) -> Int {
    guard index > 0 else {
        return 0
    }

    var newIndex = index - 1
    let caret = carets[index]
    let offset = caret.offset.x
    let line = caret.line
    while newIndex > 0 {
        let caret = carets[newIndex]
        if caret.offset.x < offset || caret.line != line {
            return newIndex
        }

        newIndex -= 1
    }

    return newIndex
}
