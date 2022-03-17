//
//  String+base64url.swift
//  Beam
//
//  Created by Julien Plu on 10/03/2022.
//

import Foundation

public extension String {
    func base64URLEscaped() -> String {
        replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
}
