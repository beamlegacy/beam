//
//  BeamTextTools.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/12/2020.
//

import Foundation

// High level manipulation:
extension BeamText {
    mutating func makeInternalLink(_ range: Swift.Range<Int>) {
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
        let link = String(t.substring(range: newRange))
        var linkCharacterSet = CharacterSet.alphanumerics
        linkCharacterSet.insert(" ")
        guard linkCharacterSet.isSuperset(of: CharacterSet(charactersIn: link)) else {
            return
        }

        let linkText = BeamText(text: link, attributes: [.internalLink(link)])
        let actualRange = range.lowerBound + start ..< range.lowerBound + end
        print("makeInternalLink range: \(range) | actual: \(actualRange)")
        replaceSubrange(actualRange, with: linkText)
    }
}
