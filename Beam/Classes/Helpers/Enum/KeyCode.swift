//
//  KeyCode.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation

enum KeyCode: UInt16 {
    case escape = 53
    case delete = 117
    case left = 123
    case right = 124
    case down = 125
    case up = 126
    case enter = 36
    case `return` = 76
    case space = 49
    case backspace = 51
    case lineFeed = 52

    case one = 18
    case two = 19
    case three = 20
    case four = 21
    case five = 23
    case six = 22
    case seven = 26
    case eight = 28
    case nine = 25
    case zero = 29

    //Used for option-S full page collect
    case s = 1

    ///Use this when you want to catch what's usually called "insert new line"
    var meansNewLine: Bool {
        switch self {
        case .enter, .return, .lineFeed:
            return true
        default:
            return false
        }
    }

    // Keycodes reference
    // https://eastmanreference.com/complete-list-of-applescript-key-codes
    // We return the key value we always expect not taking into the account the keyboard layout of the user
    // swiftlint:disable:next cyclomatic_complexity
    static func getKeyValueFrom(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case KeyCode.zero.rawValue:
            return 0
        case KeyCode.one.rawValue:
            return 1
        case KeyCode.two.rawValue:
            return 2
        case KeyCode.three.rawValue:
            return 3
        case KeyCode.four.rawValue:
            return 4
        case KeyCode.five.rawValue:
            return 5
        case KeyCode.six.rawValue:
            return 6
        case KeyCode.seven.rawValue:
            return 7
        case KeyCode.eight.rawValue:
            return 8
        case KeyCode.nine.rawValue:
            return 9
        default:
            return nil
        }
    }
}
