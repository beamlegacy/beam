//
//  PasswordManagerElements.swift
//  Beam
//
//  Created by Frank Lefebvre on 16/03/2021.
//

import Foundation
import BeamCore

enum DOMInputElementType: String, Codable {
    case text
    case email
    case password
}

enum DOMInputMode: String, Codable {
    case none
    case text
    case decimal
    case numeric
    case tel
    case search
    case email
    case url
}

struct DOMInputElement: Codable, Equatable, Hashable {
    var type: DOMInputElementType?
    var beamId: String
    var autocomplete: String?
    var autofocus: String?
    var elementClass: String?
    var name: String?
    var required: String?
    var value: String?
    var inputmode: DOMInputMode?

    private enum CodingKeys: String, CodingKey {
        case type
        case beamId = "data-beam-id"
        case autocomplete
        case autofocus
        case elementClass = "class"
        case name
        case required
        case value
        case inputmode
    }
}

extension DOMInputElement {
    var debugDescription: String {
        "Input: \(type?.rawValue ?? "(undefined/unknown)"), beamId: \(beamId), autocomplete: \(autocomplete ?? "(undefined)"), autofocus: \(autofocus ?? "(undefined)"), name: \(name ?? "(undefined)"), class: \(elementClass ?? "(undefined)"), required: \(required ?? "(undefined)"), value: \(value ?? "nil"))"
    }
}

enum DOMInputAutocomplete: String, Codable {
    case off = "off"
    case on = "on"
    case email = "email"
    case username = "username"
    case newPassword = "new-password"
    case currentPassword = "current-password"
    case tel = "tel"
}

struct DOMRect: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
}

extension DOMRect {
    var rect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
