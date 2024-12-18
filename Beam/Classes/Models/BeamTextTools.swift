//
//  BeamTextTools.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/12/2020.
//

import Foundation
import BeamCore

// High level manipulation:
extension BeamText {
    @discardableResult mutating func makeInternalLink(_ source: BeamDocumentSource, _ range: Swift.Range<Int>) -> UUID? {
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
        link = link.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard linkCharacterSet.isSuperset(of: CharacterSet(charactersIn: link)) else {
//            Logger.shared.logError("makeInternalLink for range: \(range) failed: forbidden characters in range", category: .document)
            return nil
        }

        var linkedNote: BeamNote?
        if let journalDate = BeamNoteType.dateFrom(journalDateString: link) {
            linkedNote = try? BeamNote.fetchOrCreateJournalNote(source, date: journalDate)
        } else {
            linkedNote = try? BeamNote.fetchOrCreate(source, title: link)
        }
        guard let linkedNote = linkedNote else { return nil}

        if linkedNote.children.isEmpty {
            linkedNote.addChild(BeamElement())
        }
        let linkText = BeamText(text: link, attributes: [.internalLink(linkedNote.id)])
        let actualRange = range.lowerBound + start ..< range.lowerBound + end
        Logger.shared.logInfo("makeInternalLink for range: \(range) | actual: \(actualRange)", category: .document)
        replaceSubrange(actualRange, with: linkText)

        _ = linkedNote.save(source)

        return linkedNote.id
    }

    mutating func makeLinksToNoteExplicit(_ source: BeamDocumentSource, forNote title: String) {
        text.ranges(of: title, options: .caseInsensitive).forEach { range in
            let start = text.position(at: range.lowerBound)
            let end = text.position(at: range.upperBound)
            makeInternalLink(source, start..<end)
        }
    }

    @discardableResult func extractFormatterType(from range: Swift.Range<Int>) -> [TextFormatterType] {
        let sub = extract(range: range)
        var types: [TextFormatterType] = []

        sub.ranges.forEach { range in
            range.attributes.forEach { attribute in
                switch attribute {
                case .strong:
                    if !types.contains(.bold) { types.append(.bold) }
                case .emphasis:
                    if !types.contains(.italic) { types.append(.italic) }
                case .strikethrough:
                    if !types.contains(.strikethrough) { types.append(.strikethrough) }
                case .underline:
                    if !types.contains(.underline) { types.append(.underline) }
                default:
                    break
                }
            }
        }

        return types
    }

}

public extension BeamElement {
    @discardableResult func makeInternalLink(_ source: BeamDocumentSource, _ range: Swift.Range<Int>) -> (UUID?, UUID?) {
        return (note?.id, text.makeInternalLink(source, range))
    }
}
