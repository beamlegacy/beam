//
//  String+Escaping.swift
//  BeamCore
//
//  Created by Frank Lefebvre on 10/05/2022.
//

import Foundation

public extension String {
    func javascriptEscaped() -> String {
        let charactersToEscape = "\\\"'&\n\r\t" // always replace backslash first!
        var escaped = self
        for char in charactersToEscape {
            escaped = escaped.replacingOccurrences(of: String(char), with: "\\\(char)")
        }
        return escaped
    }
}
