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
    let height: CGFloat
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
        .onHover(perform: {
            hoveringState = $0
            updateHighlightState()
        })
        .onTouchDown {
            mouseDownState = $0
            updateHighlightState()
        }
        .padding()
        .background(highlightState.backgroundColor
                        .frame(height: height, alignment: .center))
        .simultaneousGesture(
            TapGesture().onEnded {
                onChange?(.clicked)
            }
        ).frame(height: height, alignment: .center)
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
        PasswordManagerMenuCell(height: 35, onChange: { _ in }, content: {
            OtherPasswordsCell()
        })
        PasswordManagerMenuCell(height: 35, onChange: { _ in }, content: {
            PasswordsViewMoreCell(hostName: "www.github.com", onChange: { _ in })
        })
        PasswordManagerMenuCell(height: 56, onChange: { _ in }, content: {
            StoredPasswordCell(host: URL(string: "https://beamapp.co")!, username: "Beam", onChange: { _ in })
        })
    }
}
