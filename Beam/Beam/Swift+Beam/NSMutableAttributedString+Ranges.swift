//
//  NSMutableAttributedString+Ranges.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/10/2020.
//

import Foundation

public struct PositionAttribute {
    var range: NSRange
    var position: NSNumber
}

public extension NSMutableAttributedString {
    var positionAttribs: [PositionAttribute] {
        get {
            var attribs = [PositionAttribute]()
            enumerateAttribute(.sourceRange, in: NSRange(location: 0, length: length), options: .longestEffectiveRangeNotRequired) { value, range, _ in
                //swiftlint:disable:next force_cast
                attribs.append(PositionAttribute(range: range, position: value as! NSNumber))
            }
            return attribs
        }

        set {
            for v in newValue {
                addAttribute(.sourceRange, value: v.position, range: v.range)
            }
        }
    }

}

extension NSMutableAttributedString {

    static var empty: NSMutableAttributedString {
        return "".attributed
    }
}

extension NSAttributedString {

    static var paragraphSeparator: NSAttributedString {
        return String.paragraphSeparator.attributed
    }
}

extension String {

    var attributed: NSMutableAttributedString {
        return NSMutableAttributedString(string: self)
    }

    // This codepoint marks the end of a paragraph and the start of the next.
    static var paragraphSeparator: String {
        return "\u{2029}"
    }

    // This code point allows line breaking, without starting a new paragraph.
    static var lineSeparator: String {
        return "\u{2028}"
    }

    static var zeroWidthSpace: String {
        return "\u{200B}"
    }

    func replacingNewlinesWithLineSeparators() -> String {
        let trimmed = trimmingCharacters(in: .newlines)
        let lines = trimmed.components(separatedBy: .newlines)
        return lines.joined(separator: .lineSeparator)
    }
}
