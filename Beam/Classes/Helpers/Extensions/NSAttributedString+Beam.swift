//
//  NSAttributedString+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation

extension NSAttributedString {

    static var paragraphSeparator: NSAttributedString {
        return String.paragraphSeparator.attributed
    }

    var wholeRange: NSRange {
        return NSRange(location: 0, length: self.length)
    }

}
