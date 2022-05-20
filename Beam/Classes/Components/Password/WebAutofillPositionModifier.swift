//
//  WebAutofillPositionModifier.swift
//  Beam
//
//  Created by Frank Lefebvre on 06/05/2022.
//

import BeamCore
import CloudKit

final class WebAutofillPositionModifier {
    struct DisplayRule: Decodable {
        var actions: [WebAutofillAction]?
        var roles: [WebInputField.Role]?
        var iconInsets: BeamEdgeInsets
    }

    static let shared = WebAutofillPositionModifier()

    private var displayRules: [String: [DisplayRule]] = [:]

    init() {
        let decoder = JSONDecoder()
        guard let displayRulesURL = Bundle.main.url(forResource: "autofill-display", withExtension: "json") else {
            fatalError("Error while creating WebAutofillPositionModifier URL")
        }
        do {
            let displayRulesData = try Data(contentsOf: displayRulesURL)
            self.displayRules = try decoder.decode([String: [DisplayRule]].self, from: displayRulesData)
        } catch {
            fatalError("Error while decoding autofill-display.json: \(error.localizedDescription)")
        }
    }

    func inputFieldEdgeInsets(host: String, action: WebAutofillAction, role: WebInputField.Role) -> BeamEdgeInsets {
        guard let rule = displayRules[host]?.first(where: { rule in
            isEnabled(action: action, in: rule) && isEnabled(role: role, in: rule)
        }) else { return .zero }
        return rule.iconInsets
    }

    private func isEnabled(action: WebAutofillAction, in rule: DisplayRule) -> Bool {
        guard let actions = rule.actions else { return true }
        return actions.contains(action)
    }

    private func isEnabled(role: WebInputField.Role, in rule: DisplayRule) -> Bool {
        guard let roles = rule.roles else { return true }
        return roles.contains(role)
    }
}
