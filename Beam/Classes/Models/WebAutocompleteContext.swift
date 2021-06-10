//
//  WebAutocompleteContext.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/06/2021.
//

import Foundation

enum WebAutocompleteAction {
    case login
    case createAccount
    case personalInfo
    case payment
}

struct WebInputField {
    enum Role {
        case currentUsername
        case newUsername
        case currentPassword
        case newPassword
    }

    let id: String // beamId
    let role: Role
}

struct WebAutocompleteGroup {
    var action: WebAutocompleteAction
    var relatedFields: [WebInputField]
}

extension DOMInputElement {
    var decodedAutocomplete: DOMInputAutocomplete? {
        guard let autocomplete = autocomplete else {
            return nil
        }
        if let autocompleteCase = DOMInputAutocomplete(rawValue: autocomplete), autocompleteCase != .off {
            return autocompleteCase
        }
        return nil
    }

    var isPersonalInfoField: Bool {
        switch decodedAutocomplete {
        case .email:
            return true
        default:
            return false
        }
    }

    var isPaymentInfoField: Bool {
        switch decodedAutocomplete {
//        case .creditCardNumber:
//            return true
        default:
            return false
        }
    }
}

extension WebInputField {
    init(_ inputField: DOMInputElement, role: Role? = nil, action: WebAutocompleteAction? = nil) {
        self.id = inputField.beamId
        if let role = role {
            self.role = role
        } else {
            switch inputField.decodedAutocomplete {
            case .username:
                self.role = action == .createAccount ? .newUsername : .currentUsername
            case .currentPassword:
                self.role = .currentPassword
            case .newPassword:
                self.role = .newPassword
//            case .email:
//                self.role = .email
            default:
                if action == .createAccount {
                    self.role = inputField.type == .password ? .newPassword : .newUsername
                } else {
                    self.role = inputField.type == .password ? .currentPassword : .currentUsername
                }
            }
        }
    }
}

/**
 Determines the actions to be taken upon click on an input field.
 */
final class WebAutocompleteContext {
    let passwordStore: PasswordStore

    private var autocompleteFields: [WebAutocompleteAction: [WebInputField]]
    private var autocompleteGroups: [String: WebAutocompleteGroup] // key = beamId

    init(passwordStore: PasswordStore) {
        self.passwordStore = passwordStore
        self.autocompleteFields = [:]
        self.autocompleteGroups = [:]
    }

    func clear() {
        autocompleteFields.removeAll()
        autocompleteGroups.removeAll()
    }

    func update(with fields: [DOMInputElement] /* on webPage */) -> [String] {
        let fieldsWithAutocompleteAttribute = fields.filter { $0.decodedAutocomplete != nil }
        if fieldsWithAutocompleteAttribute.count == 0 {
            return update(withUntagged: fields)
        }
        // If any field has a known autocomplete attribute, we can assume all fields participating in autocomplete do.
        return update(withTagged: fieldsWithAutocompleteAttribute)
    }

    private func update(withUntagged fields: [DOMInputElement]) -> [String] {
        let passwordFields = fields.filter { $0.type == .password }
        guard fields.count > passwordFields.count else {
            clear()
            return []
        }
        switch passwordFields.count {
        case 1:
            return update(withUntagged: fields, action: .login)
        case 2:
            return update(withUntagged: fields, action: .createAccount)
        default:
            clear()
            return []
        }
    }

    private func update(withUntagged fields: [DOMInputElement], action: WebAutocompleteAction) -> [String] {
        // If any field is a password entry field, let's assume the login field is either right before or after it.
        guard let passwordIndex = fields.firstIndex(where: { $0.type == .password }) else {
            clear()
            return []
        }
        guard let usernameField = passwordIndex > 0 ? fields[passwordIndex - 1] : fields.first(where: { $0.type != .password }) else {
            clear()
            return []
        }
        let passwordFields = fields.filter { $0.type == .password }
        let autocompleteFields = [WebInputField(usernameField, role: action == .createAccount ? .newUsername : .currentUsername)] + passwordFields.map { WebInputField($0, role: action == .createAccount ? .newPassword : .currentPassword) }
        let autocompleteGroup = WebAutocompleteGroup(action: action, relatedFields: autocompleteFields)
        let autocompleteIds = autocompleteFields.map(\.id)
        let addedIds = autocompleteIds.filter { autocompleteGroups[$0] == nil }
        autocompleteGroups = autocompleteIds.reduce(into: [:]) { dict, id in
            dict[id] = autocompleteGroup
        }
        return addedIds
    }

    private func update(withTagged fields: [DOMInputElement]) -> [String] {
        let hasLoginFields = fields.contains { $0.decodedAutocomplete == .currentPassword }
        //let hasCreateAccountFields = fields.contains { $0.decodedAutocomplete == .newPassword }
        let createAccount = fields.contains { $0.decodedAutocomplete == .newPassword } && !hasLoginFields

        let loginFields = fields
            .filter { hasLoginFields && $0.decodedAutocomplete == .username || $0.decodedAutocomplete == .currentPassword }
            .map { WebInputField($0, action: .login) }
        let loginGroup = WebAutocompleteGroup(action: .login, relatedFields: loginFields)
        let loginIds = loginFields.map(\.id)
        let loginGroups = loginIds.reduce(into: [:]) { dict, id in
            dict[id] = loginGroup
        }

        let createAccountFields = fields
            .filter { createAccount && $0.decodedAutocomplete == .username || $0.decodedAutocomplete == .newPassword }
            .map { WebInputField($0, action: .createAccount) }
        let createAccountGroup = WebAutocompleteGroup(action: .createAccount, relatedFields: createAccountFields)
        let createAccountIds = createAccountFields.filter { $0.role == .newPassword }.map(\.id)
        let createAccountGroups = createAccountIds.reduce(into: [:]) { dict, id in
            dict[id] = createAccountGroup
        }

        let personalInfoFields = fields
            .filter { $0.isPersonalInfoField }
            .map { WebInputField($0) }
        let personalInfoGroup = WebAutocompleteGroup(action: .personalInfo, relatedFields: personalInfoFields)
        let personalInfoIds = personalInfoFields.map(\.id)
        let personalInfoGroups = personalInfoIds.reduce(into: [:]) { dict, id in
            dict[id] = personalInfoGroup
        }

        let paymentFields = fields
            .filter { $0.isPaymentInfoField }
            .map { WebInputField($0) }
        let paymentGroup = WebAutocompleteGroup(action: .payment, relatedFields: paymentFields)
        let paymentIds = paymentFields.map(\.id)
        let paymentGroups = paymentIds.reduce(into: [:]) { dict, id in
            dict[id] = paymentGroup
        }

        var mergedGroups = loginGroups
        mergedGroups.merge(createAccountGroups) { (current, _) in current }
        mergedGroups.merge(personalInfoGroups) { (current, _) in current }
        mergedGroups.merge(paymentGroups) { (current, _) in current }
        let addedIds = mergedGroups.keys.filter { autocompleteGroups[$0] == nil }
        autocompleteGroups = mergedGroups
        autocompleteFields = [.login: loginFields, .createAccount: createAccountFields, .personalInfo: personalInfoFields, .payment: paymentFields]
        return addedIds
    }

    func autocompleteGroup(for elementId: String) -> WebAutocompleteGroup? {
        return autocompleteGroups[elementId]
    }

    var allInputFields: [WebInputField] {
        autocompleteFields.values.flatMap { $0 }
    }
}
