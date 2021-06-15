//
//  FormatterType.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Foundation

enum TextFormatterType: String, CaseIterable {
    case h1
    case h2
    case bullet
    case numbered
    case quote
    case checkmark
    case bold
    case italic
    case strikethrough
    case underline
    case internalLink
    case link
    case code
    case unknow

    var icon: String {
        switch self {
        case .internalLink:
            return "editor-format_bidirectional"
        default:
            return "editor-format_\(rawValue)"
        }
    }
}
