//
//  PasswordManager.swift
//  Beam
//
//  Created by Frank Lefebvre on 16/03/2021.
//

import Foundation

enum DOMInputElementType: String, Codable {
    case text
    case email
    case password
}

struct DOMInputElement: Codable, Equatable, Hashable {
    var type: DOMInputElementType?
    var id: String
    var autocomplete: String?
    var autofocus: String?
    var `class`: String?
    var name: String?
    var required: String?
}

enum DOMInputAutocomplete: String, Codable {
    case off
    case email
    case username
    case newPassword = "new-password"
    case currentPassword = "current-password"
    case oneTimeCode = "one-time-code"
}

extension DOMInputElement {
    var hasMeaningfulAutocompleteAttribute: Bool {
        guard let autocomplete = autocomplete else {
            return false
        }
        guard let autocompleteCase = DOMInputAutocomplete(rawValue: autocomplete) else {
            return false
        }
        return autocompleteCase != .off
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

enum InputType {
    case login
    case password
    case newPassword
    case creditCard
}

struct AutofillInputField {
    let id: String
    let type: InputType
    var bounds: CGRect?

    init?(_ inputField: DOMInputElement) {
        guard let autocomplete = inputField.autocomplete, let fieldType = DOMInputAutocomplete(rawValue: autocomplete) else {
            return nil
        }
        id = inputField.id
        switch fieldType {
        case .email, .username:
            type = .login
        case .currentPassword:
            type = .password
        case .newPassword:
            type = .newPassword
        default:
            return nil
        }
    }

    init(inputField: DOMInputElement, type: InputType) {
        self.id = inputField.id
        self.type = type
    }
}

class PasswordManager {
    static let shared = PasswordManager()

    func autofillFields(from fields: [DOMInputElement]) -> [AutofillInputField] {
        if fields.contains(where: { $0.hasMeaningfulAutocompleteAttribute }) {
            // If any field has a known autocomplete property, we can assume all password-related fields do.
            return fields.compactMap(AutofillInputField.init)
        }
        let passwordFields = fields.filter { $0.type == .password }
        switch passwordFields.count {
        case 1:
            // If any field is a password entry field, let's assume the login field is either right before or after it.
            guard let passwordIndex = fields.firstIndex(where: { $0.type == .password }) else { return [] }
            let passwordField = AutofillInputField(inputField: fields[passwordIndex], type: .password)
            let loginField: AutofillInputField?
            if passwordIndex > 0 {
                loginField = AutofillInputField(inputField: fields[passwordIndex - 1], type: .login)
            } else if passwordIndex + 1 < fields.count {
                loginField = AutofillInputField(inputField: fields[passwordIndex + 1], type: .login)
            } else {
                loginField = nil
            }
            if let loginField = loginField {
                return [loginField, passwordField]
            }
            return [passwordField]
        case 2:
            // Two password fields: let's assume account creation with new password and password confirm.
            return passwordFields.map {
                AutofillInputField(inputField: $0, type: .newPassword)
            }
        default:
            // No password field, or too many
            return []
        }
    }
}
