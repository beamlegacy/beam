//
//  WebAutocompleteContext.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/06/2021.
//
//swiftlint:disable file_length

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
        case tel
    }

    let id: String // beamId
    let role: Role
}

struct WebAutocompleteGroup {
    var action: WebAutocompleteAction
    var relatedFields: [WebInputField]
    var isAmbiguous = false // can be part of either login or account creation, must be determined by context
}

struct WebAutocompleteRules {
    enum Condition {
        case never
        case always
        case whenPasswordField
    }

    let ignoreTextAutocompleteOff: Condition
    let ignoreEmailAutocompleteOff: Condition
    let ignorePasswordAutocompleteOff: Condition
    let discardAutocompleteAttribute: Condition

    init(ignoreTextAutocompleteOff: Condition = .whenPasswordField, ignoreEmailAutocompleteOff: Condition = .whenPasswordField, ignorePasswordAutocompleteOff: Condition = .always, discardAutocompleteAttribute: Condition = .never) {
        self.ignoreTextAutocompleteOff = ignoreTextAutocompleteOff
        self.ignoreEmailAutocompleteOff = ignoreEmailAutocompleteOff
        self.ignorePasswordAutocompleteOff = ignorePasswordAutocompleteOff
        self.discardAutocompleteAttribute = discardAutocompleteAttribute
    }

    static let `default` = Self()

    private func apply(condition: Condition, inPageContainingPasswordField pageContainsPasswordField: Bool) -> Bool {
        switch condition {
        case .never:
            return false
        case .always:
            return true
        case .whenPasswordField:
            return pageContainsPasswordField
        }
    }

    func allowUntaggedField(_ field: DOMInputElement, inPageContainingPasswordField pageContainsPasswordField: Bool) -> Bool {
        switch field.decodedAutocomplete {
        case nil:
            return true
        case .off:
            switch field.type {
            case .text:
                return apply(condition: ignoreTextAutocompleteOff, inPageContainingPasswordField: pageContainsPasswordField)
            case .email:
                return apply(condition: ignoreEmailAutocompleteOff, inPageContainingPasswordField: pageContainsPasswordField)
            case .password:
                return apply(condition: ignorePasswordAutocompleteOff, inPageContainingPasswordField: pageContainsPasswordField)
            default:
                return false
            }
        default:
            return false
        }
    }

    func allowTaggedField(_ field: DOMInputElement, inPageContainingPasswordField pageContainsPasswordField: Bool) -> Bool {
        switch field.decodedAutocomplete {
        case nil:
            return field.type == .email
        case .off:
            switch field.type {
            case .text:
                return apply(condition: ignoreTextAutocompleteOff, inPageContainingPasswordField: pageContainsPasswordField)
            case .email:
                return apply(condition: ignoreEmailAutocompleteOff, inPageContainingPasswordField: pageContainsPasswordField)
            case .password:
                return apply(condition: ignorePasswordAutocompleteOff, inPageContainingPasswordField: pageContainsPasswordField)
            default:
                return false
            }
        default:
            return true
        }
    }

    func transformField(_ field: DOMInputElement, inPageContainingPasswordField pageContainsPasswordField: Bool) -> DOMInputElement {
        var transformedField = field
        let ignoreAutocomplete = apply(condition: discardAutocompleteAttribute, inPageContainingPasswordField: pageContainsPasswordField)
        if ignoreAutocomplete {
            transformedField.autocomplete = nil
        }
        return transformedField
    }
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

    func isUsedForLogin(bestUsernameAutocomplete: DOMInputAutocomplete?) -> Bool {
        switch decodedAutocomplete {
        case .currentPassword:
            return true
        case .username, .email, .tel, .on, .off:
            return bestUsernameAutocomplete == decodedAutocomplete
        default:
            return type == .email && bestUsernameAutocomplete != .username
        }
    }

    func isUsedForAccountCreation(bestUsernameAutocomplete: DOMInputAutocomplete?) -> Bool {
        switch decodedAutocomplete {
        case .newPassword:
            return true
        case .username, .email, .tel, .on, .off:
            return bestUsernameAutocomplete == decodedAutocomplete
        default:
            return type == .email && bestUsernameAutocomplete != .username
        }
    }

    var isUntaggedLoginField: Bool {
        decodedAutocomplete == nil && type != .password
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
        case .tel:
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
            case .email, .tel:
                self.role = action == .createAccount ? .newUsername : action == .login ? .currentUsername : .email
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

    private var autocompleteRules: WebAutocompleteRules
    private var autocompleteFields: [WebAutocompleteAction: [WebInputField]]
    var autocompleteGroups: [String: WebAutocompleteGroup] // key = beamId

    init() {
        self.autocompleteRules = .default
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

        let passwordFields = fields.filter { $0.type == .password }
        let containsCurrentPasswordField = passwordFields.contains { $0.isCurrentPasswordField } || (!passwordFields.isEmpty && !passwordFields.contains { $0.isNewPasswordField })
        let containsNewPasswordField = passwordFields.contains { $0.isNewPasswordField } || (!passwordFields.isEmpty && !passwordFields.contains { $0.isCurrentPasswordField })
        let containsUsernameField = fields.contains(where: { $0.decodedAutocomplete == .username })
        let containsEmailField = fields.contains(where: { $0.decodedAutocomplete == .email })
        let containsTelephoneField = fields.contains(where: { $0.decodedAutocomplete == .tel })
        let containsAutocompleteOnField = fields.contains(where: { $0.decodedAutocomplete == .on })
        let containsUntaggedLoginField = fields.contains(where: { $0.isUntaggedLoginField })
        let bestUsernameAutocomplete: DOMInputAutocomplete? = containsUsernameField ? .username : containsEmailField ? .email : containsTelephoneField ? .tel : containsAutocompleteOnField ? .on : containsUntaggedLoginField ? nil : .off

        for field in fields {
            if (field.isUsedForLogin(bestUsernameAutocomplete: bestUsernameAutocomplete)) && containsCurrentPasswordField {
                loginFields.append(WebInputField(field, action: .login))
            }
            if (field.isUsedForAccountCreation(bestUsernameAutocomplete: bestUsernameAutocomplete)) && containsNewPasswordField {
                createAccountFields.append(WebInputField(field, action: .createAccount))
            }
            if field.isPersonalInfoField {
                personalInfoFields.append(WebInputField(field))
            }
            if field.isPaymentInfoField {
                paymentFields.append(WebInputField(field))
            }
        }

        if loginFields.isEmpty && createAccountFields.isEmpty && containsUsernameField {
            let usernameFields = fields.filter { $0.decodedAutocomplete == .username }
            loginFields = usernameFields.map { WebInputField($0, action: .login) }
            createAccountFields = usernameFields.map { WebInputField($0, action: .createAccount) }
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
        let createAccountIds = createAccountFields.filter { $0.role == .newPassword }.map(\.id) // don't suggest new password when clicking on login field
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

    // Minimal implementation for now.
    // If more special cases arise it could make sense to define rules in a plist file and create a separate class.
    private func autocompleteRules(for host: String?) -> WebAutocompleteRules {
        switch host {
        case "pinterest.com", "netflix.com", "maderasbarber.com":
            return WebAutocompleteRules(discardAutocompleteAttribute: .whenPasswordField)
        default:
            return .default
        }
    }

    func update(with rawFields: [DOMInputElement], on host: String?) -> [String] {
        autocompleteRules = autocompleteRules(for: host)
        let pageContainsPasswordField = rawFields.contains { $0.type == .password }
        let fields = rawFields.map { autocompleteRules.transformField($0, inPageContainingPasswordField: pageContainsPasswordField) }
        let fieldsWithAutocompleteAttribute = fields.filter { $0.decodedAutocomplete != nil && $0.decodedAutocomplete != .off }
        let fieldIds: [String]
        if fieldsWithAutocompleteAttribute.count == 0 {
            let untaggedFields = fields.filter { autocompleteRules.allowUntaggedField($0, inPageContainingPasswordField: pageContainsPasswordField) }
            Logger.shared.logDebug("Untagged candidates: \(untaggedFields.map { $0.debugDescription })", category: .passwordManager)
            fieldIds = update(withUntagged: untaggedFields)
        } else {
            // If any field has a known autocomplete attribute, we can NOT safely assume all fields participating in autocomplete do.
            let candidateFields = fields.filter { autocompleteRules.allowTaggedField($0, inPageContainingPasswordField: pageContainsPasswordField) }
            Logger.shared.logDebug("Tagged candidates: \(candidateFields.map { $0.debugDescription })", category: .passwordManager)
            fieldIds = update(withTagged: candidateFields)
        }
        Logger.shared.logDebug("Autocomplete groups: \(autocompleteGroups)", category: .passwordManager)
        return fieldIds
    }

    private func update(withUntagged fields: [DOMInputElement]) -> [String] {
        let passwordFields = fields.filter { $0.type == .password }
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
        guard let passwordIndex = fields.firstIndex(where: { $0.type == .password }) else {
            clear()
            return []
        }
        // If any field is a password entry field, the login field is probably right before it.
        // We build an ordered list of candidate username fields by taking all (obviously non-password) fields before the first password field in reversed order,
        // followed by all non-password fields after the first password field in natural order.
        var usernameFields = fields[0..<passwordIndex].reversed() + fields[passwordIndex...].filter { $0.type != .password }
        if usernameFields.contains(where: { $0.decodedAutocomplete == nil}) {
            usernameFields.removeAll(where: { $0.decodedAutocomplete == .off })
        }
        let passwordFields = fields.filter { $0.type == .password }
        let autocompleteUsernamePasswordFields = usernameFields.map { WebInputField($0, role: action == .createAccount ? .newUsername : .currentUsername) } + passwordFields.map { WebInputField($0, role: action == .createAccount ? .newPassword : .currentPassword) }
        autocompleteFields = [action: autocompleteUsernamePasswordFields]
        let autocompleteGroup = WebAutocompleteGroup(action: action, relatedFields: autocompleteUsernamePasswordFields, isAmbiguous: true)
        let autocompleteIds = autocompleteUsernamePasswordFields.map(\.id)
        let addedIds = autocompleteIds.filter { autocompleteGroups[$0] == nil }
        autocompleteGroups = autocompleteIds.reduce(into: [:]) { dict, id in
            dict[id] = autocompleteGroup
        }
        return addedIds
    }

    private func update(withTagged fields: [DOMInputElement]) -> [String] {
        autocompleteFields = getAutocompleteFields(fields)
        Logger.shared.logDebug("Autocomplete Fields: \(autocompleteFields)", category: .passwordManager)
        let fieldGroups = getAutocompleteGroups(fields) // FIXME: for some strange reason getAutocompleteGroups() ignores fields, and used autocompleteFields
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

    var allInputFieldIds: [String] {
        Array(Set(allInputFields.map(\.id)))
    }
}
