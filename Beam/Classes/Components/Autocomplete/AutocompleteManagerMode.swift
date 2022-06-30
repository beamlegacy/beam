//
//  AutocompleteManagerMode.swift
//  Beam
//
//  Created by Remi Santos on 17/06/2022.
//

import Foundation

extension AutocompleteManager {
    enum Mode: Equatable {
        case noteCreation
        case tabGroup(group: TabGroup)
        case general

        var isGeneral: Bool {
            if case .general = self { return true }
            return false
        }

        var displaysSearchEngineResults: Bool {
            if case .general = self { return true }
            return false
        }

        func shouldUpdateSearchQueryOnSelection(for result: AutocompleteResult) -> (allow: Bool, replacement: String?) {
            switch self {
            case .noteCreation: return (false, nil)
            case .tabGroup:
                let isAction = result.source == .action
                return (!isAction, isAction ? "" : nil)
            case .general: return (true, nil)
            }
        }
    }
}
