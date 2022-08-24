//
//  WebAutofillMenuSelectionHandler.swift
//  Beam
//
//  Created by Frank Lefebvre on 08/08/2022.
//

import Foundation

final class WebAutofillMenuSelectionHandler {
    enum Action {
        case none
        case refresh
        case select(String)
    }

    private var hoveredCellId: String?
    private var keyboardSelectionIndex: Int?
    private var keyboardSelectedCellId: String?
    private var keyboardSelectableCellIds: [String] = []

    func handleStateChange(itemId: String, newState: WebFieldAutofillMenuCellState) -> Bool {
        switch newState {
        case .idle:
            if hoveredCellId != nil {
                hoveredCellId = nil
                return true
            }
        case .hovering:
            if hoveredCellId != itemId {
                hoveredCellId = itemId
                keyboardSelectedCellId = nil
                keyboardSelectionIndex = nil
                return true
            }
        default:
            break
        }
        return false
    }

    func highlightState(of itemId: String) -> Bool {
        itemId == hoveredCellId ?? keyboardSelectedCellId
    }

    func update(selectableIds: [String]) {
        keyboardSelectableCellIds = selectableIds
    }

    func onKeyDown(with event: NSEvent) -> Action {
        switch event.keyCode {
        case KeyCode.up.rawValue:
            return moveKeyboardSelection(by: -1) ? .refresh : .none
        case KeyCode.down.rawValue:
            return moveKeyboardSelection(by: 1) ? .refresh : .none
        case KeyCode.enter.rawValue, KeyCode.return.rawValue:
            if let itemId = hoveredCellId ?? keyboardSelectedCellId {
                return .select(itemId)
            } else {
                return .none
            }
        default:
            return .none
        }
    }

    private func hoveredCellIndex() -> Int? {
        guard let hoveredCellId = hoveredCellId else {
            return nil
        }
        return keyboardSelectableCellIds.firstIndex(of: hoveredCellId)
    }

    private func moveKeyboardSelection(by increment: Int) -> Bool {
        let newIndex = (keyboardSelectionIndex ?? hoveredCellIndex())?.advanced(by: increment) ?? 0
        guard newIndex >= 0, newIndex < keyboardSelectableCellIds.count else {
            return false
        }
        keyboardSelectionIndex = newIndex
        keyboardSelectedCellId = keyboardSelectableCellIds[newIndex]
        hoveredCellId = nil
        return true
    }
}
