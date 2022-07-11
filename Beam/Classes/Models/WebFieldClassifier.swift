//
//  WebFieldClassifier.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/06/2021.
//
//swiftlint:disable file_length

import Foundation
import BeamCore

enum WebAutofillAction: String, Decodable {
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
        case ignored

        var isPassword: Bool {
            self == .currentPassword || self == .newPassword
        }
    }

    let id: String // beamId
    let role: Role
}

struct WebAutofillGroup {
    var action: WebAutofillAction
    var relatedFields: [WebInputField]
    var isAmbiguous = false // can be part of either login or account creation, must be determined by context

    func field(id: String) -> WebInputField? {
        relatedFields.first { $0.id == id }
    }
}

struct WebAutofillRules {
    enum Condition {
        case never
        case always
        case whenPasswordFieldPresent
        case forAutocompleteValues([String])
    }

    let ignoreTextAutocompleteOff: Condition
    let ignoreEmailAutocompleteOff: Condition
    let ignoreTelAutocompleteOff: Condition
    let ignorePasswordAutocompleteOff: Condition
    let discardAutocompleteAttribute: Condition
    let discardTypeAttribute: Condition
    let ignoreUntaggedPasswordFieldAlone: Bool
    let mergeIncompleteCardExpirationDate: Bool

    init(ignoreTextAutocompleteOff: Condition = .whenPasswordFieldPresent, ignoreEmailAutocompleteOff: Condition = .whenPasswordFieldPresent, ignoreTelAutocompleteOff: Condition = .whenPasswordFieldPresent, ignorePasswordAutocompleteOff: Condition = .always, discardAutocompleteAttribute: Condition = .never, discardTypeAttribute: Condition = .never, ignoreUntaggedPasswordFieldAlone: Bool = false, mergeIncompleteCardExpirationDate: Bool = false) {
        self.ignoreTextAutocompleteOff = ignoreTextAutocompleteOff
        self.ignoreEmailAutocompleteOff = ignoreEmailAutocompleteOff
        self.ignoreTelAutocompleteOff = ignoreTelAutocompleteOff
        self.ignorePasswordAutocompleteOff = ignorePasswordAutocompleteOff
        self.discardAutocompleteAttribute = discardAutocompleteAttribute
        self.discardTypeAttribute = discardTypeAttribute
        self.ignoreUntaggedPasswordFieldAlone = ignoreUntaggedPasswordFieldAlone
        self.mergeIncompleteCardExpirationDate = mergeIncompleteCardExpirationDate
    }

    static let `default` = Self()

    private func apply(condition: Condition, to field: DOMInputElement, inPageContainingPasswordField pageContainsPasswordField: Bool) -> Bool {
        switch condition {
        case .never:
            return false
        case .always:
            return true
        case .whenPasswordFieldPresent:
            return pageContainsPasswordField
        case .forAutocompleteValues(let values):
            guard let autocomplete = field.autocomplete else { return false }
            return values.contains(autocomplete)
        }
    }

    func allowField(_ field: DOMInputElement, pageContainsTaggedField: Bool, pageContainsPasswordField: Bool) -> Bool {
        switch field.decodedAutocomplete {
        case .off:
            switch field.type {
            case .text:
                return apply(condition: ignoreTextAutocompleteOff, to: field, inPageContainingPasswordField: pageContainsPasswordField)
            case .email:
                return apply(condition: ignoreEmailAutocompleteOff, to: field, inPageContainingPasswordField: pageContainsPasswordField)
            case .tel:
                return apply(condition: ignoreTelAutocompleteOff, to: field, inPageContainingPasswordField: pageContainsPasswordField)
            case .password:
                return apply(condition: ignorePasswordAutocompleteOff, to: field, inPageContainingPasswordField: pageContainsPasswordField)
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
        let ignoreAutocomplete = apply(condition: discardAutocompleteAttribute, to: field, inPageContainingPasswordField: pageContainsPasswordField)
        if ignoreAutocomplete {
            transformedField.autocomplete = nil
        }
        let ignoreType = apply(condition: discardTypeAttribute, to: field, inPageContainingPasswordField: pageContainsPasswordField)
        if ignoreType {
            transformedField.type = nil
        }
        return transformedField
    }
}

private extension DOMInputElement {
    /// decodedAutocomplete returns matching DOMInputAutocomplete case.
    /// With no matching autocomplete attribute value is found default to `.on`
    var decodedAutocomplete: DOMInputAutocomplete? {
        guard let autocomplete = autocomplete else {
            return nil
        }
        if let autocompleteCase = autocomplete
            .components(separatedBy: .whitespaces)
            .compactMap(DOMInputAutocomplete.fromString)
            .first {
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
        decodedAutocomplete == .on
    }

    var isCurrentPasswordField: Bool {
        decodedAutocomplete == .currentPassword
    }

    var isNewPasswordField: Bool {
        decodedAutocomplete == .newPassword
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
}

extension WebInputField {
    init(_ inputField: DOMInputElement, role: Role? = nil, action: WebAutofillAction? = nil) {
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
        let autofillGroups: [String: WebAutofillGroup]
        let activeFields: [String]

        static let empty = ClassifierResult(autofillGroups: [:], activeFields: [])

        var allInputFields: [WebInputField] {
            let fields = autofillGroups.values.flatMap(\.relatedFields)
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

    fileprivate struct Introspector {
        enum FilteringStep {
            case raw
            case visible
            case transformed
            case candidate
            case evaluated([WebAutofillAction: WeightedRole])
        }

        private(set) var fields: [DOMInputElement]
        private(set) var filtering: [String: FilteringStep]

        init(fields: [DOMInputElement]) {
            self.fields = fields
            self.filtering = fields.reduce(into: [:]) { $0[$1.beamId] = .raw }
        }

        mutating func update(fields: [DOMInputElement], step: FilteringStep) {
            fields.map(\.beamId).forEach { filtering[$0] = step }
        }

        mutating func update(evaluated: [EvaluatedField]) {
            evaluated.forEach { filtering[$0.element.beamId] = .evaluated($0.evaluation) }
        }

        static var debugHeader: [String] {
            DOMInputElement.debugHeader + ["last seen", "login role", "login match", "signup role", "signup match", "payment role", "payment match", "personal role", "personal match"]
        }

        private func debugValues(field: DOMInputElement) -> [String] {
            var columns = field.debugValues
            switch filtering[field.beamId] {
            case nil:
                columns += ["(nil)", "", "", "", "", "", "", "", ""]
            case .raw:
                columns += ["raw", "", "", "", "", "", "", "", ""]
            case .visible:
                columns += ["visible", "", "", "", "", "", "", "", ""]
            case .transformed:
                columns += ["rules", "", "", "", "", "", "", "", ""]
            case .candidate:
                columns += ["candidate", "", "", "", "", "", "", "", ""]
            case .evaluated(let dict):
                columns += ["evaluated"]
                columns += dict[.login]?.debugValues ?? ["", ""]
                columns += dict[.createAccount]?.debugValues ?? ["", ""]
                columns += dict[.payment]?.debugValues ?? ["", ""]
                columns += dict[.personalInfo]?.debugValues ?? ["", ""]
            }
            return columns
        }

        var debugDescription: String {
            ([Self.debugHeader.joined(separator: "\t")]
             + fields.map {
                debugValues(field: $0).joined(separator: "\t")
            })
            .joined(separator: "\r")
        }
    }

    fileprivate enum Match: Equatable, Comparable {
        case never
        case score(Int)
        case always

        var debugDescription: String {
            switch self {
            case .never:
                return "never"
            case .score(let score):
                return "\(score)"
            case .always:
                return "always"
            }
        }
    }

    fileprivate struct WeightedRole {
        var role: WebInputField.Role
        var match: Match

        var debugValues: [String] {
            [role.rawValue, match.debugDescription]
        }
    }

    fileprivate struct RoleInContext {
        var role: WebInputField.Role
        var action: WebAutofillAction
    }

    fileprivate struct EvaluatedField {
        var element: DOMInputElement
        var evaluation: [WebAutofillAction: WeightedRole]

        func bestMatch(thresholds: [WebAutofillAction: Match]) -> RoleInContext? {
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

        func roleForAction(_ action: WebAutofillAction) -> WebInputField.Role? {
            guard let weightedRole = evaluation[action], weightedRole.match != .never else { return nil }
            return weightedRole.role
        }
    }

    private var autofillRules: WebAutofillRules

    init() {
        self.autofillRules = .default
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func evaluateForPassword(action: WebAutofillAction, field: DOMInputElement, bestUsernameAutocomplete: DOMInputAutocomplete?, bias: Int) -> WeightedRole? {
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
            score = 1000 // ignore score given by autocomplete if not already identified as password
        case .email:
            score += 100
        default:
            break
        }
        if field.decodedAutocomplete == bestUsernameAutocomplete && field.type != .password {
            score += 500
        }
        field.decodedHints.forEach { value in
            if value.contains("login") || value.contains("account") || value.contains("user") {
                score += 10
            }
            if value.contains("email") {
                score += 5
            }
            if value.contains("first") || value.contains("last") {
                score -= 10
            }
            if value.contains("cvv") || value.contains("csc") || value.contains("cardverificationnumber") {
                score -= 500
            }
        }
        return .init(role: expectedRole, match: .score(score + bias))
    }

    // swiftlint:disable:next cyclomatic_complexity
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
            var result: WeightedRole?
            field.decodedHints.forEach { value in
                if value.contains("cardnum") || value.contains("ccnum") {
                    result = .init(role: .cardNumber, match: .score(800))
                } else if value.contains("cardholder") || value.contains("holdername") || value.contains("cardname") || value.contains("ccname") {
                    result = .init(role: .cardHolder, match: .score(800))
                } else if value.contains("cardexpiry") || value.contains("cardexpiration") || value.contains("expirationdate") || value.contains("expdate") {
                    result = .init(role: .cardExpirationDate, match: .score(800))
                } else if value.contains("expirationmonth") || value.contains("expmonth") || value.contains("ccmonth") {
                    result = .init(role: .cardExpirationMonth, match: .score(800))
                } else if value.contains("expirationyear") || value.contains("expyear") || value.contains("ccyear") {
                    result = .init(role: .cardExpirationYear, match: .score(800))
                } else if value.contains("expiration") {
                    result = .init(role: .cardExpirationDate, match: .score(790))
                } else if value.contains("cvv") || value.contains("csc") || value.contains("cardverificationnumber") {
                    result = .init(role: .ignored, match: .score(800))
                }
            }
            return result
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
            var evaluation: [WebAutofillAction: WeightedRole] = [:]
            evaluation[.login] = evaluateForPassword(action: .login, field: field, bestUsernameAutocomplete: bestUsernameAutocomplete, bias: biasTowardLogin)
            evaluation[.createAccount] = evaluateForPassword(action: .createAccount, field: field, bestUsernameAutocomplete: bestUsernameAutocomplete, bias: biasTowardAccountCreation)
            evaluation[.payment] = evaluateForPayment(field: field)
            return EvaluatedField(element: field, evaluation: evaluation)
        }
    }

    // Minimal implementation for now.
    // If more special cases arise it could make sense to define rules in a plist file and create a separate class.
    private func autofillRules(for host: String?) -> WebAutofillRules {
        switch host {
        case "app.beamapp.co":
            return WebAutofillRules(ignorePasswordAutocompleteOff: .never, ignoreUntaggedPasswordFieldAlone: true)
        case "pinterest.com", "maderasbarber.com", "testrail.io":
            return WebAutofillRules(discardAutocompleteAttribute: .whenPasswordFieldPresent)
        case "agoda.com", "figma.com":
            return WebAutofillRules(discardAutocompleteAttribute: .forAutocompleteValues(["new-password"]))
        case "netflix.com", "payment-netflix.form.lvh.me":
            return WebAutofillRules(ignoreTelAutocompleteOff: .always, discardAutocompleteAttribute: .whenPasswordFieldPresent, mergeIncompleteCardExpirationDate: true)
        case "calendar.amie.so":
            return WebAutofillRules(discardAutocompleteAttribute: .forAutocompleteValues(["new-password"]), discardTypeAttribute: .forAutocompleteValues(["new-password"]))
        default:
            return .default
        }
    }

    func classify(rawFields allRawFields: [DOMInputElement], on host: String?) -> ClassifierResult {
        autofillRules = autofillRules(for: host)
        var introspector = Introspector(fields: allRawFields)
        let rawFields = allRawFields.filter(includedInEvaluation)
        introspector.update(fields: rawFields, step: .visible)
        let pageContainsPasswordField = rawFields.contains { $0.isCompatibleWithPassword }
        let pageContainsNonPasswordField = rawFields.contains { $0.type != .password }
        let fields = rawFields.compactMap { autofillRules.transformField($0, inPageContainingPasswordField: pageContainsPasswordField, nonPasswordField: pageContainsNonPasswordField) }
        introspector.update(fields: fields, step: .transformed)
        let pageContainsTaggedField = fields.contains { $0.decodedAutocomplete != nil && $0.decodedAutocomplete != .off }
        let allowedFields = fields.filter { autofillRules.allowField($0, pageContainsTaggedField: pageContainsTaggedField, pageContainsPasswordField: pageContainsPasswordField) }
        introspector.update(fields: allowedFields, step: .candidate)

        let passwordFields = fields.filter { $0.isCompatibleWithPassword }
        let containsPasswordFieldsUsableForLogin = !passwordFields.isEmpty && !passwordFields.contains { $0.isNewPasswordField }
        let containsPasswordFieldsUsableForNewAccount = !passwordFields.isEmpty && !passwordFields.contains { $0.isCurrentPasswordField }
        let biasTowardLogin = containsPasswordFieldsUsableForLogin ? 4 : 1 // give a slight edge to login by default
        let biasTowardAccountCreation = (containsPasswordFieldsUsableForNewAccount ? 3 : 0) + (passwordFields.count >= 2 ? 2 : 0)

        let evaluatedFields = evaluateFields(allowedFields, biasTowardLogin: biasTowardLogin, biasTowardAccountCreation: biasTowardAccountCreation)
        introspector.update(evaluated: evaluatedFields)
        let ambiguousPasswordAction = containsPasswordFieldsUsableForLogin && containsPasswordFieldsUsableForNewAccount
        let minimumLoginMatch = evaluatedFields.bestMatch(forRole: .currentUsername)
        let minimiumCreateAccountMatch = evaluatedFields.bestMatch(forRole: .newUsername)
        let pageContainsCardNumberField = evaluatedFields.contains { $0.compatibleWithRole(.cardNumber) }
        let pageContainsIncompleteCardExpirationDate = evaluatedFields.contains { $0.compatibleWithRole(.cardExpirationMonth) } != evaluatedFields.contains { $0.compatibleWithRole(.cardExpirationYear) }
        let thresholds: [WebAutofillAction: Match] = [
            .login: max(minimumLoginMatch, containsPasswordFieldsUsableForLogin ? .score(0) : .score(900)),
            .createAccount: max(minimiumCreateAccountMatch, containsPasswordFieldsUsableForNewAccount ? .score(0) : .score(900)),
            .payment: pageContainsCardNumberField ? .score(0) : .always // This can be changed to `.payment: .always` to disable heuristics based on `class` and `name` attributes.
        ]
        Logger.shared.logDebug("Autofill Introspection:\r\(introspector.debugDescription)", category: .webAutofillInternal)
        return makeClassifierResult(fields: evaluatedFields, thresholds: thresholds, ambiguousPasswordAction: ambiguousPasswordAction, incompleteCardExpirationDate: pageContainsIncompleteCardExpirationDate)
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

    private func makeClassifierResult(fields: [EvaluatedField], thresholds: [WebAutofillAction: Match], ambiguousPasswordAction: Bool, incompleteCardExpirationDate: Bool) -> ClassifierResult {
        Logger.shared.logDebug("Making classifier results for: \(fields)", category: .webAutofillInternal)
        var groups: [String: WebAutofillGroup] = [:]
        var activeFields: [String] = []
        for field in fields {
            if let group = makeAutofillGroup(from: field, in: fields, thresholds: thresholds, ambiguousPasswordAction: ambiguousPasswordAction, incompleteCardExpirationDate: incompleteCardExpirationDate) {
                let id = field.element.beamId
                groups[id] = group
                activeFields.append(id)
            }
        }
        Logger.shared.logDebug("Autocomplete groups: \(groups)", category: .webAutofillInternal)
        return ClassifierResult(autofillGroups: groups, activeFields: activeFields)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func makeAutofillGroup(from field: EvaluatedField, in fields: [EvaluatedField], thresholds: [WebAutofillAction: Match], ambiguousPasswordAction: Bool, incompleteCardExpirationDate: Bool) -> WebAutofillGroup? {
        guard let best = field.bestMatch(thresholds: thresholds) else { return nil }
        Logger.shared.logDebug("Best match for: \(field): \(best)", category: .webAutofillInternal)
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
            return WebAutofillGroup(action: .login, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
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
            return WebAutofillGroup(action: .createAccount, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .currentUsername:
            var relatedFields = fields
                .filter { $0.compatibleWithRole(.currentPassword) }
                .map { WebInputField(id: $0.element.beamId, role: .currentPassword) }
            relatedFields.append(WebInputField(id: field.element.beamId, role: .currentUsername))
            return WebAutofillGroup(action: .login, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .newUsername:
            var relatedFields = fields
                .filter { $0.compatibleWithRole(.newPassword) }
                .map { WebInputField(id: $0.element.beamId, role: .newPassword) }
            relatedFields.append(WebInputField(id: field.element.beamId, role: .newUsername))
            return WebAutofillGroup(action: .createAccount, relatedFields: relatedFields, isAmbiguous: ambiguousPasswordAction)
        case .cardNumber, .cardHolder, .cardExpirationDate, .cardExpirationMonth, .cardExpirationYear:
            let relatedFields = fields.compactMap { otherField -> WebInputField? in
                guard var role = otherField.roleForAction(.payment) else { return nil }
                if incompleteCardExpirationDate && autofillRules.mergeIncompleteCardExpirationDate && (role == .cardExpirationMonth || role == .cardExpirationYear) {
                    role = .cardExpirationDate
                }
                return WebInputField(id: otherField.element.beamId, role: role)
            }
            return WebAutofillGroup(action: .payment, relatedFields: relatedFields)
        default:
            return nil
        }
    }
}

private extension Array where Element == WebFieldClassifier.EvaluatedField {
    func bestMatch(forRole role: WebInputField.Role) -> WebFieldClassifier.Match {
        map { $0.matchForRole(role) }.max() ?? .never
    }
}

private extension DOMInputElement {
    var decodedHints: [String] {
        var components = elementClass?.components(separatedBy: .whitespaces) ?? []
        if let name = name {
            components.append(name)
        }
        if let elementId = elementId {
            components.append(elementId)
        }
        return components.map { String($0.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).lowercased() }
    }
}
