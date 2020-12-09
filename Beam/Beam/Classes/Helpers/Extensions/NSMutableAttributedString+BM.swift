//
//  NSMutableAttributedString+BM.swift
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

    static var empty: NSMutableAttributedString {
        return "".attributed
    }

    var positionAttribs: [PositionAttribute] {
        get {
            var attribs = [PositionAttribute]()
            enumerateAttribute(.sourcePos, in: NSRange(location: 0, length: length), options: .longestEffectiveRangeNotRequired) { value, range, _ in
                //swiftlint:disable:next force_cast
                attribs.append(PositionAttribute(range: range, position: value as! NSNumber))
            }
            return attribs
        }

        set {
            for v in newValue {
                addAttribute(.sourcePos, value: v.position, range: v.range)
            }
        }
    }

    func addAttributes(_ attribs: [NSAttributedString.Key: Any]) -> Self {
        self.addAttributes(attribs, range: wholeRange)
        return self
    }

    func replaceAttributes(_ attribs: [NSAttributedString.Key: Any]) -> Self {
        for attrib in attribs {
            self.removeAttribute(attrib.key, range: self.wholeRange)
        }
        self.addAttributes(attribs, range: wholeRange)
        return self
    }
}
