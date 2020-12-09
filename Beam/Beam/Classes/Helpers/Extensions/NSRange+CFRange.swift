//
//  NSRange+CFRange.swift
//  Beam
//
//  Created by Sebastien Metrot on 28/09/2020.
//

import Foundation

extension NSRange {
    init(range: CFRange) {
        //swiftlint:disable legacy_constructor
        self = NSMakeRange(range.location == kCFNotFound ? NSNotFound : range.location, range.length)
    }
}
