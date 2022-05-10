//
//  WebFieldClassifier.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/06/2021.
//
//swiftlint:disable file_length

import Foundation
import BeamCore

enum WebAutocompleteAction: String, Decodable {
    case login
    case createAccount
    case personalInfo
    case payment

    var isPasswordRelated: Bool {
        self == .login || self == .createAccount
    }
}

struct WebInputField {
    enum Role: String, Decodable {
        case currentUsername
        case newUsername
        case currentPassword
        case newPassword
        case email
        case tel
        case cardNumber
        case cardHolder
        case cardExpirationDate
        case cardExpirationMonth
        case cardExpirationYear

        var isPassword: Bool {
            self == .currentPassword || self == .newPassword
        }
    }

    let id: String // beamId
    let role: Role
}

struct WebAutocompleteGroup {
    var action: WebAutocompleteAction
    var relatedFields: [WebInputField]
    var isAmbiguous = false // can be part of either login or account creation, must be determined by context

    func field(id: String) -> WebInputField? {
        relatedFields.first { $0.id == id }
    }
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
    let ignoreUntaggedPasswordFieldAlone: Bool

    init(ignoreTextAutocompleteOff: Condition = .whenPasswordField, ignoreEmailAutocompleteOff: Condition = .whenPasswordField, ignorePasswordAutocompleteOff: Condition = .always, discardAutocompleteAttribute: Condition = .never, ignoreUntaggedPasswordFieldAlone: Bool = false) {
        self.ignoreTextAutocompleteOff = ignoreTextAutocompleteOff
        self.ignoreEmailAutocompleteOff = ignoreEmailAutocompleteOff
        self.ignorePasswordAutocompleteOff = ignorePasswordAutocompleteOff
        self.discardAutocompleteAttribute = discardAutocompleteAttribute
        self.ignoreUntaggedPasswordFieldAlone = ignoreUntaggedPasswordFieldAlone
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

    func allowField(_ field: DOMInputElement, pageContainsTaggedField: Bool, pageContainsPasswordField: Bool) -> Bool {
        switch field.decodedAutocomplete {
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

    func transformField(_ field: DOMInputElement, inPageContainingPasswordField pageContainsPasswordField: Bool, nonPasswordField pageContainsNonPasswordField: Bool) -> DOMInputElement? {
        if ignoreUntaggedPasswordFieldAlone && field.type == .password && field.autocomplete == nil && !pageContainsNonPasswordField {
            return nil
        }
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

    var isUntaggedLoginField: Bool {
        decodedAutocomplete == nil && type != .password
    }

    var isCompatibleWithPassword: Bool {
        guard type == .password else { return false }
        switch decodedAutocomplete {
        case .currentPassword, .newPassword, .off, .on, .none:
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
final class WebFieldClassifier {

    struct ClassifierResult {
        let autocompleteGroups: [String: WebAutocompleteGroup]
        let activeFields: [String]

        static let empty = ClassifierResult(autocompleteGroups: [:], activeFields: [])

        var allInputFields: [WebInputField] {
            let fields = autocompleteGroups.values.flatMap(\.relatedFields)
            // Deduplicate fields by id.
            // This could be replaced with an ordered set if we choose to include the Collections package.
            var fieldIds = Set<String>()
            var deduplicatedFields = [WebInputField]()
            for field in fields {
                if fieldIds.insert(field.id).inserted {
                    deduplicatedFields.append(field)
                }
            }
            return deduplicatedFields
        }
    }

    fileprivate enum Match: Equatable, Comparable {
        case never
        case score(Int)
        case always
    }

    fileprivate struct WeightedRole {
        var role: WebInputField.Role
        var match: Match
    }

    fileprivate struct RoleInContext {
        var role: WebInputField.Role
        var action: WebAutocompleteAction
    }

    fileprivate struct EvaluatedField {
        var element: DOMInputElement
        var evaluation: [WebAutocompleteAction: WeightedRole]

        func bestMatch(thresholds: [WebAutocompleteAction: Match]) -> RoleInContext? {
            let candidates = evaluation.filter { $0.value.match != .never }
            let perfectMatches = candidates.filter { $0.value.match == .always }
            if let perfectMatch = perfectMatches.first {
                if perfectMatches.count >= 2 {
                    Logger.shared.logWarning("Field matches \(perfectMatches.count) actions perfectly.", category: .passwordManager)
                }
                return RoleInContext(role: perfectMatch.value.role, action: perfectMatch.key)
            }
            let bestMatches = candidates
                .filter { $0.value.match >= thresholds[$0.key, default: .never] }
                .sorted { pair1, pair2 in
                    pair1.value.match < pair2.value.match
                }
            guard let bestMatch = bestMatches.last else { return nil }
            if case let .score(score) = bestMatch.value.match, score < 0 { return nil }
            return RoleInContext(role: bestMatch.value.role, action: bestMatch.key)
        }

        func compatibleWithRole(_ role: WebInputField.Role) -> Bool {
            evaluation.values.contains { weightedRole in
                weightedRole.role == role && weightedRole.match != .never
            }
        }

        func matchForRole(_ role: WebInputField.Role) -> Match {
            evaluation.values.compactMap { weightedRole -> Match? in
                weightedRole.role == role ? weightedRole.match : nil
            }.sorted().last ?? .never
        }

        func roleForAction(_ action: WebAutocompleteAction) -> WebInputField.Role? {
            guard let weightedRole = evaluation[action], weightedRole.match != .never else { return nil }
            return weightedRole.role
        }
    }

    private var autocompleteRules: WebAutocompleteRules

    init() {
        self.autocompleteRules = .default
    }

    private func evaluateForPassword(action: WebAutocompleteAction, field: DOMInputElement, bestUsernameAutocomplete: DOMInputAutocomplete?, bias: Int) -> WeightedRole? {
        let usernameRole: WebInputField.Role
        let passwordRole: WebInputField.Role
        switch action {
        case .login:
            usernameRole = .currentUsername
            passwordRole = .currentPassword
        case .createAccount:
            usernameRole = .newUsername
            passwordRole = .newPassword
        default:
            return nil
        }
        let expectedRole = field.type == .password ? passwordRole : usernameRole
        var score = 0
        switch field.decodedAutocomplete {
        case .currentPassword:
            return .init(role: passwordRole, match: action == .login ? .always : .never)
        case .newPassword:
            return .init(role: passwordRole, match: action == .login ? .never : .always)
        case .username:
            score = 500
        case .email:
            score = bestUsernameAutocomplete == .username ? -10 : 100
        case .tel:
            score = bestUsernameAutocomplete == .username ? -10 : 50
        case .on:
            score = bestUsernameAutocomplete == .username ? -10 : 20
        case nil:
            score = bestUsernameAutocomplete == .username ? -10 : 0
        case .off:
            score = -10
        default:
            return nil
        }
        switch field.type {
        case .password:
            score += 1000
        case .email:
            score += 100
        default:
            break
        }
        if field.decodedAutocomplete == bestUsernameAutocomplete {
            score += 500
        }
        [field.elementClass, field.name]
            .compactMap { $0?.lowercased() }
            .forEach { value in
                if value.contains("login") || value.contains("account") || value.contains("user") {
                    score += 10
                }
                if value.contains("email") {
                    score += 5
                }
                if value.contains("first") || value.contains("last") {
                    score -= 10
                }
            }
        return .init(role: expectedRole, match: .score(score + bias))
    }

    private func evaluateForPayment(field: DOMInputElement) -> WeightedRole? {
        switch field.decodedAutocomplete {
        case .creditCardFullName, .creditCardFamilyName:
            return .init(role: .cardHolder, match: .always)
        case .creditCardNumber:
            return .init(role: .cardNumber, match: .always)
        case .creditCardExpirationDate:
            return .init(role: .cardExpirationDate, match: .always)
        case .creditCardExpirationMonth:
            return .init(role: .cardExpirationMonth, match: .always)
        case .creditCardExpirationYear:
            return .init(role: .cardExpirationYear, match: .always)
        default:
            return nil
        }
    }

    private func evaluateFields(_ fields: [DOMInputElement], biasTowardLogin: Int, biasTowardAccountCreation: Int) -> [EvaluatedField] {
        let containsUsernameField = fields.contains(where: { $0.decodedAutocomplete == .username })
        let containsEmailField = fields.contains(where: { $0.decodedAutocomplete == .email })
        let containsTelephoneField = fields.contains(where: { $0.decodedAutocomplete == .tel })
        let containsAutocompleteOnField = fields.contains(where: { $0.isAutocompleteOnField })
        let containsUntaggedLoginField = fields.contains(where: { $0.isUntaggedLoginField })
        let bestUsernameAutocomplete: DOMInputAutocomplete? = containsUsernameField ? .username : containsEmailField ? .email : containsTelephoneField ? .tel : containsAutocompleteOnField ? .on : containsUntaggedLoginField ? nil : .off

        return fields.compactMap { field in
            var evaluation: [WebAutocompleteAction: WeightedRole] = [:]
            evaluation[.login] = evaluateForPassword(action: .login, field: field, bestUsernameAutocomplete: bestUsernameAutocomplete, bias: biasTowardLogin)
            evaluation[.createAccount] = evaluateForPassword(action: .createAccount, field: field, bestUsernameAutocomplete: bestUsernameAutocomplete, bias: biasTowardAccountCreation)
            evaluation[.payment] = evaluateForPayment(field: field)
            return EvaluatedField(element: field, evaluation: evaluation)
        }
    }

    // Minimal implementation for now.
    // If more special cases arise it could make sense to define rules in a plist file and create a separate class.
    private func autocompleteRules(for host: String?) -> WebAutocompleteRules {
        switch host {
        case "app.beamapp.co":
            return WebAutocompleteRules(ignorePasswordAutocompleteOff: .never, ignoreUntaggedPasswordFieldAlone: true)
        case "pinterest.com", "netflix.com", "maderasbarber.com":
            return WebAutocompleteRules(discardAutocompleteAttribute: .whenPasswordField)
        default:
            return .default
        }
    }

    func classify(rawFields allRawFields: [DOMInputElement], on host: String?) -> ClassifierResult {
        autocompleteRules = autocompleteRules(for: host)
        let rawFields = allRawFields.filter(includedInEvaluation)
        let pageContainsPasswordField = rawFields.contains { $0.isCompatibleWithPassword }
        let pageContainsNonPasswordField = rawFields.contains { $0.type != .password }
        let fields = rawFields.compactMap { autocompleteRules.transformField($0, inPageContainingPasswordField: pageContainsPasswordField, nonPasswordField: pageContainsNonPasswordField) }
        let pageContainsTaggedField = fields.contains { $0.decodedAutocomplete != nil && $0.decodedAutocomplete != .off }
        let allowedFields = fields.filter { autocompleteRules.allowField($0, pageContainsTaggedField: pageContainsTaggedField, pageContainsPasswordField: pageContainsPasswordField)}
        Logger.shared.logDebug("Candidates: \(allowedFields.map { $0.debugDescription })", category: .passwordManagerInternal)

        let passwordFields = fields.filter { $0.isCompatibleWithPassword }
        let containsPasswordFieldsUsableForLogin = !passwordFields.isEmpty && !passwordFields.contains { $0.isNewPasswordField }
        let containsPasswordFieldsUsableForNewAccount = !passwordFields.isEmpty && !passwordFields.contains { $0.isCurrentPasswordField }
        let biasTowardLogin = containsPasswordFieldsUsableForLogin ? 4 : 1 // give a slight edge to login by default
        let biasTowardAccountCreation = (containsPasswordFieldsUsableForNewAccount ? 3 : 0) + (passwordFields.count >= 2 ? 2 : 0)
        Logger.shared.logDebug("Biases: login = \(biasTowardLogin), account creation = \(biasTowardAccountCreation)", category: .passwordManagerInternal)

        let evaluatedFields = evaluateFields(allowedFields, biasTowardLogin: biasTowardLogin, biasTowardAccountCreation: biasTowardAccountCreation)
        let ambiguousPasswordAction = containsPasswordFieldsUsableForLogin && containsPasswordFieldsUsableForNewAccount
        let minimumLoginMatch = evaluatedFields.bestMatch(forRole: .currentUsername)
        let minimiumCreateAccountMatch = evaluatedFields.bestMatch(forRole: .newUsername)
        let thresholds: [WebAutocompleteAction: Match] = [
            .login: max(minimumLoginMatch, containsPasswordFieldsUsableForLogin ? .score(0) : .score(900)),
            .createAccount: max(minimiumCreateAccountMatch, containsPasswordFieldsUsableForNewAccount ? .score(0) : .score(900))
        ]
        return makeClassifierResult(fields: evaluatedFields, thresholds: thresholds, ambiguousPasswordAction: ambiguousPasswordAction)
    }

    private func includedInEvaluation(_ inputElement: DOMInputElement) -> Bool {
        guard inputElement.visible else { return false }
        guard let inputMode = inputElement.inputmode else { return true }
        switch inputMode {
        case .text, .tel, .email, .numeric:
            return true
        default:
            return false
        }
    }

    private func makeClassifierResult(fields: [EvaluatedField], thresholds: [WebAutocompleteAction: Match], ambiguousPasswordAction: Bool) -> ClassifierResult {
        Logger.shared.logDebug("Making classifier results for: \(fields)", category: .passwordManagerInternal)
        var groups: [String: WebAutocompleteGroup] = [:]
        var activeFields: [String] = []
        for field in fields {
            if let group = makeAutocompleteGroup(from: field, in: fields, thresholds: thresholds, ambiguousPasswordAction: ambiguousPasswordAction) {
                let id = field.element.beamId
                groups[id] = group
                activeFields.append(id)
            }
        }
        Logger.shared.logDebug("Autocomplete groups: \(groups)", category: .passwordManagerInternal)
        return ClassifierResult(autocompleteGroups: groups, activeFields: activeFields)
    }

    private func makeAutocompleteGroup(from field: EvaluatedField, in fields: [EvaluatedField], thresholds: [WebAutocompleteAction: Match], ambiguousPasswordAction: Bool) -> WebAutocompleteGroup? {
        guard let best = field.bestMatch(thresholds: thresholds) else { return nil }
        Logger.shared.logDebug("Best match for: \(field): \(best)", category: .passwordManagerInternal)
        switch best.role {
        case .currentPassword:
            var relatedFields = fields
                .filter { $0.compatibleWithRole(.currentPassword) }
                .map { WebInputField(id: $0.element.beamId, role: .currentPassword) }
            let usernameField = fields
                .filter { $0.compatibleWithRole(.currentUsername) }
                .sorted { $0.matchForRole(.currentUsername) < $1.matchForRole(.currentUsername) }
                .last
            if let usernameField = usernameField {
                relatedFields.append(WebInputField(id: usernameField.element.beamId, role: .currentUsername))
            }
            return WebAutocompleteGroup(action: .login, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .newPassword:
            var relatedFields = fields
                .filter { $0.compatibleWithRole(.newPassword) }
                .map { WebInputField(id: $0.element.beamId, role: .newPassword) }
            let usernameField = fields
                .filter { $0.compatibleWithRole(.newUsername) }
                .sorted { $0.matchForRole(.newUsername) < $1.matchForRole(.newUsername) }
                .last
            if let usernameField = usernameField {
                relatedFields.append(WebInputField(id: usernameField.element.beamId, role: .newUsername))
            }
            return WebAutocompleteGroup(action: .createAccount, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .currentUsername:
            var relatedFields = fields
                .filter { $0.compatibleWithRole(.currentPassword) }
                .map { WebInputField(id: $0.element.beamId, role: .currentPassword) }
            relatedFields.append(WebInputField(id: field.element.beamId, role: .currentUsername))
            return WebAutocompleteGroup(action: .login, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .newUsername:
            var relatedFields = fields
                .filter { $0.compatibleWithRole(.newPassword) }
                .map { WebInputField(id: $0.element.beamId, role: .newPassword) }
            relatedFields.append(WebInputField(id: field.element.beamId, role: .newUsername))
            return WebAutocompleteGroup(action: .createAccount, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .cardNumber, .cardHolder, .cardExpirationDate, .cardExpirationMonth, .cardExpirationYear:
            let relatedFields = fields.compactMap { otherField -> WebInputField? in
                guard let role = otherField.roleForAction(.payment) else { return nil }
                return WebInputField(id: otherField.element.beamId, role: role)
            }
            return WebAutocompleteGroup(action: .payment, relatedFields: relatedFields)
        default:
            return nil
        }
    }
}

fileprivate extension Array where Element == WebFieldClassifier.EvaluatedField {
    func bestMatch(forRole role: WebInputField.Role) -> WebFieldClassifier.Match {
        map { $0.matchForRole(role) }.max() ?? .never
    }
}
