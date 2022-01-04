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

struct PasswordManagerMenuCell<Content: View>: View {
    enum CellType {
        case autofill
        case action
    }

    let type: CellType
    let height: CGFloat
    let onChange: ((PasswordManagerMenuCellState) -> Void)?
    let content: () -> Content

    private let highlightCornerRadius: CGFloat = 6
    private let contentPadding: CGFloat = 6

    @Environment(\.colorScheme) private var colorScheme

    @State private var highlightState: PasswordManagerMenuCellState = .idle
    @State private var hoveringState = false
    @State private var mouseDownState = false

    var body: some View {
        HStack(spacing: 0) {
            content()
            Spacer()
                .layoutPriority(-1)
        }
        .padding(.horizontal, type == .autofill ? 0 : contentPadding)
        .onHover(perform: {
            hoveringState = $0
            updateHighlightState()
        })
        .onTouchDown {
            mouseDownState = $0
            updateHighlightState()
        }
        .padding(10) // minimum... define in content view instead
        .background(cellBackground)
        .simultaneousGesture(
            TapGesture().onEnded {
                onChange?(.clicked)
            }
        )
        .frame(height: height, alignment: .center)
        .padding(.horizontal, type == .autofill ? contentPadding : 0)
    }

    private var cellBackground: some View {
        let color: Color
        let cornerRadius: CGFloat
        switch type {
        case .autofill:
            color = autofillBackgroundColor
            cornerRadius = highlightCornerRadius
        case .action:
            color = actionBackgroundColor
            cornerRadius = 0
        }
        return color
            .blendMode(colorScheme == .light ? .multiply : .screen)
            .cornerRadius(cornerRadius)
    }

    private var autofillBackgroundColor: Color {
        switch highlightState {
        case .idle, .clicked:
            return .clear
        case .hovering:
            return BeamColor.WebFieldAutofill.autofillCellBackgroundHovered.swiftUI
        case .down:
            return BeamColor.WebFieldAutofill.autofillCellBackgroundClicked.swiftUI
        }
    }

    private var actionBackgroundColor: Color {
        switch highlightState {
        case .idle, .clicked:
            return .clear
        case .hovering:
            return BeamColor.WebFieldAutofill.actionCellBackgroundHovered.swiftUI
        case .down:
            return BeamColor.WebFieldAutofill.actionCellBackgroundClicked.swiftUI
        }
    }

    private func updateHighlightState() {
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
