//
//  PasswordManagerMenuCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/03/2021.
//

import SwiftUI

enum PasswordManagerMenuCellState {
    case idle
    case hovering
    case down
    case clicked
}

extension PasswordManagerMenuCellState {
    var backgroundColor: Color {
        switch self {
        case .idle, .clicked:
            return Color.clear
        case .hovering:
            return BeamColor.Passwords.hoverBackground.swiftUI
        case .down:
            return BeamColor.Passwords.activeBackground.swiftUI
        }
    }
}

struct PasswordManagerMenuCell<Content: View>: View {

    let onChange: ((PasswordManagerMenuCellState) -> Void)?
    let content: () -> Content

    @State private var highlightState: PasswordManagerMenuCellState = .idle
    @State private var hoveringState = false
    @State private var mouseDownState = false

    var body: some View {
        HStack(spacing: 0) {
            content()
            Spacer()
                .layoutPriority(-1)
        }
        .padding()
        .background(highlightState.backgroundColor)
        .onHover(perform: {
            hoveringState = $0
            updateHighlightState()
        })
        .onTouchDown {
            mouseDownState = $0
            updateHighlightState()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                onChange?(.clicked)
            }
        )
    }

    func updateHighlightState() {
        let newHighlightState: PasswordManagerMenuCellState
        if mouseDownState {
            newHighlightState = .down
        } else if hoveringState {
            newHighlightState = .hovering
        } else {
            newHighlightState = .idle
        }
        if highlightState != newHighlightState {
            highlightState = newHighlightState
            onChange?(highlightState)
        }
    }
}

struct PasswordManagerMenuCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordManagerMenuCell(onChange: { _ in }, content: {
            Text("Hello World")
        })
    }
}
