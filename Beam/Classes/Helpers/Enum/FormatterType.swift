//
//  FormatterType.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Foundation

enum FormatterType: String, CaseIterable {
    case h1
    case h2
    case bullet
    case numbered
    case quote
    case checkmark
    case italic
    case strikethrough
    case link
    case code

    static var all: [FormatterType] {
        return [.h1, .h2, .bullet, .numbered, .quote, .checkmark, .italic, .strikethrough, .link, .code]
    }
}
