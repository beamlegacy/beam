//
//  NSMutableAttributedString+Range.swift
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
