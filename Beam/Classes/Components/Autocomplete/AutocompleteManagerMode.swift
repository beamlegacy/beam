//
//  AutocompleteManagerMode.swift
//  Beam
//
//  Created by Remi Santos on 17/06/2022.
//

import Foundation
import SwiftUI

extension AutocompleteManager {
    enum Mode: Equatable {
        static func == (lhs: AutocompleteManager.Mode, rhs: AutocompleteManager.Mode) -> Bool {
            switch lhs {
            case .noteCreation:
                if case .noteCreation = rhs { return true }
                else { return false }
            case .general: return rhs.isGeneral
            case .tabGroup(let groupL):
                if case .tabGroup(let groupR) = rhs { return groupL == groupR }
                else { return false }
            case .customView: return false
            }
        }

        case noteCreation
        case tabGroup(group: TabGroup)
        case customView(view: AnyView)
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
            case .noteCreation, .customView: return (false, nil)
            case .tabGroup:
                let isAction = result.source == .action
                return (!isAction, isAction ? "" : nil)
            case .general: return (true, nil)
            }
        }
    }
}
