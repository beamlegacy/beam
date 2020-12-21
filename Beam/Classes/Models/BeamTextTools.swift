//
//  BeamTextTools.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/12/2020.
//

import Foundation

// String additions:
extension BeamText {
    func prefix(_ count: Int) -> BeamText {
        return extract(range: 0 ..< count)
    }

    func suffix(_ count: Int) -> BeamText {
        let len = self.count
        return extract(range: len - count ..< len)
    }

    func clamp(_ range: Swift.Range<Int>) -> Swift.Range<Int> {
        return text.clamp(range)
    }

    func clamp(_ position: Int) -> Int {
        return min(max(0, position), count)
    }

    func range(_ start: Int, _ end: Int) -> Swift.Range<String.Index> {
        return text.range(start, end)
    }

    func range(from r: Swift.Range<Int>) -> Swift.Range<String.Index> {
        return text.range(from: r)
    }

    func index(at position: Int) -> String.Index {
        return text.index(at: position)
    }

    var wholeRange: Swift.Range<Int> {
        return Int(0)..<Int(count)
    }

    func position(at index: String.Index) -> Int {
        return text.position(at: index)
    }

    func position(after pos: Int) -> Int {
        return text.position(after: pos)
    }

    func position(before pos: Int) -> Int {
        return text.position(before: pos)
    }

//    public func description(_ range: Range<Index>) -> String {
//        return "Range from \(position(at: range.lowerBound)) to \(position(at: range.upperBound)) [\(position(at: range.upperBound) - position(at: range.lowerBound))]"
//    }

    func substring(from: Int, to: Int) -> String {
        return text.substring(from: from, to: to)
    }

    func substring(range: Swift.Range<Int>) -> String {
        return text.substring(range: range)
    }

    mutating func replaceSubrange(_ range: Swift.Range<Int>, with string: String) {
        removeSubrange(range)
        insert(string, at: range.lowerBound)
    }

    mutating func replaceSubrange(_ range: Swift.Range<Int>, with text: BeamText) {
        removeSubrange(range)
        insert(text, at: range.lowerBound)
    }

    func hasPrefix(_ string: String) -> Bool {
        return text.hasPrefix(string)
    }
}

extension BeamText: Equatable {
    static func == (lhs: BeamText, rhs: BeamText) -> Bool {
        return lhs.ranges == rhs.ranges
    }
}

extension BeamText {
    var json: String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return "<error while encoding \(self)>" }
        return String(data: data, encoding: .utf8) ?? "<error while making json string for \(self)>"
    }

    var jsonPretty: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return "<error while encoding \(self)>" }
        return String(data: data, encoding: .utf8) ?? "<error while making json string for \(self)>"
    }
}

// High level manipulation:
extension BeamText {
    mutating func makeInternalLink(_ range: Swift.Range<Int>) -> Bool {
        let text = self.extract(range: range)
        let t = text.text

        var prefix = ""
        var i = t.startIndex
        while CharacterSet.whitespacesAndNewlines.contains(t.unicodeScalars[i]) && i < t.endIndex {
            let next = t.index(after: i)
            prefix.append(String(t[i ..< next]))
            i = next
        }

        var postfix = ""
        let rt = String(t.reversed())
        i = rt.startIndex
        while CharacterSet.whitespacesAndNewlines.contains(rt.unicodeScalars[i]) && i < rt.endIndex {
            let next = rt.index(after: i)
            postfix.append(String(rt[i ..< next]))
            i = next
        }
        let start = prefix.count
        let end = t.count - (postfix.count)

        let newRange = start ..< end
        var link = String(t.substring(range: newRange))
        while link.contains("  ") {
            link = link.replacingOccurrences(of: "  ", with: " ")
        }
        var linkCharacterSet = CharacterSet.alphanumerics
        linkCharacterSet.insert(" ")
        guard linkCharacterSet.isSuperset(of: CharacterSet(charactersIn: link)) else {
            Logger.shared.logError("makeInternalLink for range: \(range) failed: forbidden characters in range", category: .document)
            return false
        }

        let linkText = BeamText(text: link, attributes: [.internalLink(link)])
        let actualRange = range.lowerBound + start ..< range.lowerBound + end
        Logger.shared.logInfo("makeInternalLink for range: \(range) | actual: \(actualRange)", category: .document)
        replaceSubrange(actualRange, with: linkText)

        return true
    }

    var internalLinks: [Range] {
        var links = [Range]()
        for range in ranges {
            for attribute in range.attributes {
                switch attribute {
                case .internalLink:
                    links.append(range)
                default:
                    break
                }
            }
        }

        return links
    }
}
