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
    case number
    case tel
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
    var elementId: String?
    var elementClass: String?
    var name: String?
    var required: String?
    var value: String?
    var inputmode: DOMInputMode?
    var visible: Bool

    private enum CodingKeys: String, CodingKey {
        case type
        case beamId = "data-beam-id"
        case autocomplete
        case autofocus
        case elementId = "id"
        case elementClass = "class"
        case name
        case required
        case value
        case inputmode
        case visible
    }
}

extension DOMInputElement {
    var debugDescription: String {
        "Input: \(type?.rawValue ?? "(undefined/unknown)"), beamId: \(beamId), visible: \(visible), autocomplete: \(autocomplete ?? "(undefined)"), autofocus: \(autofocus ?? "(undefined)"), inputmode: \(inputmode?.rawValue ?? "(undefined)"), id: \(elementId ?? "(undefined)"), name: \(name ?? "(undefined)"), class: \(elementClass ?? "(undefined)"), required: \(required ?? "(undefined)"), value: \(value ?? "nil"))"
    }

    static var debugHeader: [String] {
        ["beamId", "type", "visible", "autocomplete", "autofocus", "inputmode", "id", "name", "class", "required", "value"]
    }

    var debugValues: [String] {
        [beamId, unwrap(type?.rawValue), "\(visible)", unwrap(autocomplete), unwrap(autofocus), unwrap(inputmode?.rawValue), unwrap(elementId), unwrap(name), unwrap(elementClass), unwrap(required), unwrap(value)]
    }

    private func unwrap(_ value: String?) -> String {
        value ?? "(nil)"
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
    case creditCardFullName = "cc-name"
    case creditCardGivenName = "cc-given-name"
    case creditCardAdditionalName = "cc-additional-name"
    case creditCardFamilyName = "cc-family-name"
    case creditCardNumber = "cc-number"
    case creditCardExpirationDate = "cc-exp"
    case creditCardExpirationMonth = "cc-exp-month"
    case creditCardExpirationYear = "cc-exp-year"
    case creditCardSecurityCode = "cc-csc"
    case creditCardType = "cc-type"
}

extension DOMInputAutocomplete {
    private static let matchingDict: [String: Self] = [
        "cardholder-name": .creditCardFullName,
        "cc-expiry": .creditCardExpirationDate
    ]

    static func fromString(_ string: String) -> Self? {
        if let value = Self(rawValue: string) {
            return value
        }
        return matchingDict[string]
    }
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
