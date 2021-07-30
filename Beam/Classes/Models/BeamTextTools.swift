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
    //swiftlint:disable:next function_body_length
    @discardableResult mutating func makeInternalLink(_ range: Swift.Range<Int>, createNoteIfNeeded: Bool) -> UUID? {
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

        var _linkID = BeamNote.idForNoteNamed(link, false)
        if _linkID == nil && createNoteIfNeeded {
            let note = BeamNote.create(AppDelegate.main.data.documentManager, title: link)
            note.addChild(BeamElement())
            _linkID = note.id
            note.save(documentManager: AppDelegate.main.data.documentManager)
        }
        guard let linkID = _linkID else { return nil }
        let linkText = BeamText(text: link, attributes: [.internalLink(linkID)])
        let actualRange = range.lowerBound + start ..< range.lowerBound + end
        Logger.shared.logInfo("makeInternalLink for range: \(range) | actual: \(actualRange)", category: .document)
        replaceSubrange(actualRange, with: linkText)

        // Notes that are created by makeInternalLink shouldn't have a score of 0 as they are explicit
        let linkedNote = BeamNote.fetchOrCreate(AppDelegate.main.data.documentManager, title: link)
        let created = linkedNote.score == 0
        if created {
            // this note has just been created
            linkedNote.createdByUser()
        }

        linkedNote.referencedByUser()

        if created {
            // make sure it's saved at least once
            linkedNote.save(documentManager: AppDelegate.main.data.documentManager)
        }

        return linkedNote.id
    }

    mutating func makeLinksToNoteExplicit(forNote title: String) {
        text.ranges(of: title).forEach { range in
            let start = text.position(at: range.lowerBound)
            let end = text.position(at: range.upperBound)
            makeInternalLink(start..<end, createNoteIfNeeded: true)
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
    @discardableResult func makeInternalLink(_ range: Swift.Range<Int>, createNoteIfNeeded: Bool) -> Bool {
        return note?.id != nil &&
            text.makeInternalLink(range, createNoteIfNeeded: createNoteIfNeeded) != nil
    }
}
