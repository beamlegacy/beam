//
//  String+LoremIpsum.swift
//  Beam
//
//  Created by Sebastien Metrot on 28/09/2020.
//

import Foundation

public extension String {
    static var loremIpsum: String { """
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
"""
    }

    static var loremIpsumMD: String { """
Lorem **ipsum dolor** sit amet, *consectetur* adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore **_magna aliqua_**. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
"""
    }

    static var loremIpsumSmall: String { """
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
"""
    }

    static var loremIpsumSmallMD: String { """
Lorem **ipsum dolor** sit amet, *consectetur* adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore **_magna aliqua_**.
"""
    }

    func duplicate(_ count: Int) -> String {
        var str = ""
        for _ in 0 ..< count {
            str.append(self)
        }

        return str
    }

    static func bullet() -> String {
        return "\u{2022}"
    }

    static func tabs(_ count: Int) -> String {
        return "\t".duplicate(count)
    }

    static func spaces(_ count: Int) -> String {
        return " ".duplicate(count)
    }

    static func random(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
