//
//  Caret.swift
//  Beam
//
//  Created by Sebastien Metrot on 29/04/2021.
//

// Carets have 2 edges (leading = before the character, trailing = after it)
// Some Carets are skipable, they represent virtual characters such as images/icons inserted into the text that have no actual existance in the source string and we must skip over them when moving the caret with the curso keys

import Foundation

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

public struct Caret {
    public var offset: CGPoint
    /// indexInSource is the index of the character in source string
    public var indexInSource: Int
    public var indexOnScreen: Int
    public var edge: CaretEdge
    public var inSource: Bool
    public var line: Int

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

public func filterCarets(_ carets: [Caret], filter: CaretFilter) -> [Caret] {
    carets.compactMap { caret -> Caret? in
        return (!filter.contains(.traillingEdge) || caret.edge.isLeading)
            && (!filter.contains(.notInSource) || caret.inSource)
            ? caret : nil
    }
}

public func sortAndSourceCarets(_ carets: [Caret], sourceOffset: Int, notInSourcePositions: [Int]) -> [Caret] {
    var count = sourceOffset
    let sorted = carets.sorted { (lhs, rhs) -> Bool in
        if lhs.indexOnScreen < rhs.indexOnScreen { return true }
        if (lhs.indexOnScreen == rhs.indexOnScreen) && (lhs.offset.x < rhs.offset.x) { return true }

        return false
    }

    let indexed = sorted.map { caret -> Caret in
        let inSource = !notInSourcePositions.binaryContains(caret.indexOnScreen)
        var c = caret
        c.indexInSource = count
        c.inSource = inSource
        count += (!inSource || caret.edge.isLeading) ? 0 : 1
        return c
    }

    return indexed
}

public func nextCaret(for index: Int, in carets: [Caret]) -> Int {
    guard index < carets.count - 1 else {
        //swiftlint:disable:next print
//        print("[1]nextCaret \(index) -> \(index) \(carets[index].debugDescription)")
        return index
    }

    let position = carets[index].positionOnScreen
    var newIndex = index + 1
    while newIndex + 1 < carets.count {
        let caret = carets[newIndex]
        if caret.positionOnScreen > position && caret.edge.isLeading {
            //swiftlint:disable:next print
//            print("[2]nextCaret \(index) -> \(newIndex) \(carets[newIndex].debugDescription)")
            return newIndex
        }

        newIndex += 1
    }

    //swiftlint:disable:next print
//    print("[3]nextCaret \(index) -> \(newIndex) \(carets[newIndex].debugDescription)")
    return newIndex
}

public func previousCaret(for index: Int, in carets: [Caret]) -> Int {
    let position = carets[index].positionOnScreen
    var newIndex = index
    while (carets[newIndex].positionOnScreen >= position) &&
          (newIndex - 1 >= 0) {
        newIndex -= 1
    }

    return newIndex
}
