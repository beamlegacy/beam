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

        func shouldUpdateSearchQueryOnSelection(for result: AutocompleteResult) -> Bool {
            switch self {
            case .noteCreation, .tabGroup: return false
            case .general: return true
            }
        }
    }
}
