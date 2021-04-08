//
//  String+Calculations.swift
//  BeamCore
//
//  Created by Remi Santos on 08/04/2021.
//

import Foundation

public extension String {
    var numberOfWords: Int {
        var count = 0
        let range = startIndex..<endIndex
        enumerateSubstrings(in: range, options: [.byWords, .substringNotRequired, .localized], { _, _, _, _ -> Void in
            count += 1
        })
        return count
    }
}
