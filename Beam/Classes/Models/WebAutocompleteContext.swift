//
//  WebAutocompleteContext.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/06/2021.
//

import Foundation
import BeamCore

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
        case email
    }

    let id: String // beamId
    let role: Role
}

struct WebAutocompleteGroup {
    var action: WebAutocompleteAction
    var relatedFields: [WebInputField]
}

extension DOMInputElement {
    /// decodedAutocomplete returns matching DOMInputAutocomplete case.
    /// With no matching autocomplete attribute value is found default to `.on`
    var decodedAutocomplete: DOMInputAutocomplete? {
        guard let autocomplete = autocomplete else {
            return nil
        }
        if let autocompleteCase = DOMInputAutocomplete(rawValue: autocomplete) {
            return autocompleteCase
        }
        return DOMInputAutocomplete.off
    }

    var isLoginField: Bool {
        switch decodedAutocomplete {
        case .email:
            return true
        case .username:
            return true
        case .currentPassword:
            return true
        default:
            return false
        }
    }

    var isAutocompleteOnField: Bool {
        switch decodedAutocomplete {
        case .on:
            return true
        default:
            return false
        }
    }

    var isCurrentPasswordField: Bool {
        switch decodedAutocomplete {
        case .currentPassword:
            return true
        default:
            return false
        }
    }

    var isNewPasswordField: Bool {
        switch decodedAutocomplete {
        case .newPassword:
            return true
        default:
            return false
        }
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
            case .email:
                self.role = .email
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
    var autocompleteGroups: [String: WebAutocompleteGroup] // key = beamId

    init(passwordStore: PasswordStore) {
        self.passwordStore = passwordStore
        self.autocompleteFields = [:]
        self.autocompleteGroups = [:]
    }

    /// Takes a set of DOMInputElements and loops through them. Based on the field type and all fields in the set,
    /// the DOMInputElements are sorted into one of 4 groups. When they are added to the group They are converted from
    /// DOMInputElement to WebInfoField. If no matching group is found the field is omitted.
    /// - Parameter fields: Set of Form input fields.
    /// - Returns: Groups of inputs keys on AutocompleteAction.
    fileprivate func getAutocompleteFields(_ fields: [DOMInputElement]) -> [WebAutocompleteAction: [WebInputField]] {
        var loginFields: [WebInputField] = []
        var createAccountFields: [WebInputField] = []
        var personalInfoFields: [WebInputField] = []
        var paymentFields: [WebInputField] = []

        for field in fields {
            let containsCurrentPasswordField = fields.contains { $0.isCurrentPasswordField }
            let containsNewPasswordField = fields.contains { $0.isNewPasswordField }

            if (field.isLoginField || field.isAutocompleteOnField) && !containsNewPasswordField {
                loginFields.append(WebInputField(field, action: .login))
            } else if field.isNewPasswordField && containsCurrentPasswordField {
                createAccountFields.append(WebInputField(field, action: .createAccount))
            } else if field.isPersonalInfoField {
                personalInfoFields.append(WebInputField(field))
            } else if field.isPaymentInfoField {
                paymentFields.append(WebInputField(field))
            }
        }

        return [
            .login: loginFields,
            .createAccount: createAccountFields,
            .personalInfo: personalInfoFields,
            .payment: paymentFields
        ]
    }

    /// Get and parse all login fields from `autocompleteFields[.login]`
    /// - Returns: Deduplicated dict of inputs keyed on (Beam) id
    fileprivate func getLoginGroups() -> [String: WebAutocompleteGroup] {
        guard let loginFields = autocompleteFields[.login] else { return [:] }
        let loginGroup = WebAutocompleteGroup(action: .login, relatedFields: loginFields)
        let loginIds = loginFields.map(\.id)
        return loginIds.reduce(into: [:]) { dict, id in
            dict[id] = loginGroup
        }
    }

    /// Get and parse all create account fields from `autocompleteFields[.createAccount]`
    /// - Returns: Deduplicated dict of inputs keyed on (Beam) id
    fileprivate func getCreateAccountGroups() -> [String: WebAutocompleteGroup] {
        guard let createAccountFields = autocompleteFields[.createAccount] else { return [:] }
        let createAccountGroup = WebAutocompleteGroup(action: .createAccount, relatedFields: createAccountFields)
        let createAccountIds = createAccountFields.filter { $0.role == .newPassword }.map(\.id)
        return createAccountIds.reduce(into: [:]) { dict, id in
            dict[id] = createAccountGroup
        }
    }

    /// Get and parse all personal info fields from `autocompleteFields[.personalInfo]`
    /// - Returns: Deduplicated dict of inputs keyed on (Beam) id
    fileprivate func getPersonalInfoGroups() -> [String: WebAutocompleteGroup] {
        guard let personalInfoFields = autocompleteFields[.personalInfo] else { return [:] }
        let personalInfoGroup = WebAutocompleteGroup(action: .personalInfo, relatedFields: personalInfoFields)
        let personalInfoIds = personalInfoFields.map(\.id)
        return personalInfoIds.reduce(into: [:]) { dict, id in
            dict[id] = personalInfoGroup
        }
    }

    /// Get and parse all payment fields from `autocompleteFields[.payment]`
    /// - Returns: Deduplicated dict of inputs keyed on (Beam) id
    fileprivate func getPaymentGroups() -> [String: WebAutocompleteGroup] {
        guard let paymentFields = autocompleteFields[.payment] else { return [:] }
        let paymentGroup = WebAutocompleteGroup(action: .payment, relatedFields: paymentFields)
        let paymentIds = paymentFields.map(\.id)
        return paymentIds.reduce(into: [:]) { dict, id in
            dict[id] = paymentGroup
        }
    }

    /// Get, parse and merge a set of DOMInputElements into AutocompleteGroups
    /// - Parameter fields: Set of form input fields.
    /// - Returns: Deduplicated dict of inputs keyed on (Beam) id
    fileprivate func getAutocompleteGroups(_ fields: [DOMInputElement]) -> [String: WebAutocompleteGroup] {
        let loginGroups = getLoginGroups()
        let createAccountGroups = getCreateAccountGroups()
        let personalInfoGroups = getPersonalInfoGroups()
        let paymentGroups = getPaymentGroups()

        var mergedGroups = loginGroups
        mergedGroups.merge(createAccountGroups) { (current, _) in current }
        mergedGroups.merge(personalInfoGroups) { (current, _) in current }
        mergedGroups.merge(paymentGroups) { (current, _) in current }
        return mergedGroups
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
        autocompleteFields = getAutocompleteFields(fields)
        let fieldGroups = getAutocompleteGroups(fields)
        let addedIds = fieldGroups.keys.filter { autocompleteGroups[$0] == nil }
        autocompleteGroups = fieldGroups
        return addedIds
    }

    func autocompleteGroup(for elementId: String) -> WebAutocompleteGroup? {
        return autocompleteGroups[elementId]
    }

    var allInputFields: [WebInputField] {
        autocompleteFields.values.flatMap { $0 }
    }
}
