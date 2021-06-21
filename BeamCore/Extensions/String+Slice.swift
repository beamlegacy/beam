//
//  String+Slice.swift
//  BeamCore
//
//  Created by Stef Kors on 18/06/2021.
//  Source: https://stackoverflow.com/a/52514158/3199999

import Foundation

public extension String {
    /// Usage: `let slicedString = yourString.slice(from: "\"", to: "\"")`
    /// - Parameters:
    ///   - from: String to start range
    ///   - to: String to end range
    /// - Returns: Sliced string between `from` and `to`
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
}
