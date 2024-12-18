//
//  ToolbarButton.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

struct ToolbarButton: View {
    @Environment(\.isMainWindow) private var isMainWindow: Bool
    @Environment(\.isEnabled) private var isEnabled

    var icon: String
    var customIconSize: CGSize?
    var customContainerSize: CGSize?
    var action: (() -> Void)?

    @State var isHovering: Bool = false
    @State var isTouchDown: Bool = false

    private var foregroundColor: Color {
        guard isMainWindow else {
            return BeamColor.ToolBar.buttonForegroundInactiveWindow.swiftUI
        }
        if !isEnabled {
            return BeamColor.ToolBar.buttonForegroundDisabled.swiftUI
        }
        if isHovering || isTouchDown {
            return BeamColor.ToolBar.buttonForegroundHoveredClicked.swiftUI
        }
        return BeamColor.ToolBar.buttonForeground.swiftUI
    }

    private var backgroundColor: Color? {
        guard isTouchDown else { return nil }
        return BeamColor.ToolBar.buttonBackgroundClicked.swiftUI
    }

    var body: some View {
        Icon(name: icon, size: customIconSize ?? CGSize(width: 24, height: 24), color: foregroundColor)
            .blendModeLightMultiplyDarkScreen()
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .frame(width: customContainerSize?.width ?? 28, height: customContainerSize?.height ?? 28)
            .background(
                backgroundColor
                    .blendModeLightMultiplyDarkScreen()
            )
            .cornerRadius(6)
            .onHover { isHovering = $0 }
            .onTouchDown { isTouchDown = $0 }
            .simultaneousGesture(TapGesture().onEnded {
                action?()
            })
            .allowsHitTesting(isEnabled)
    }
}

struct ToolbarButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HStack {
                ToolbarButton(icon: "nav-journal")
                ToolbarButton(icon: "nav-journal", isHovering: true)
                ToolbarButton(icon: "nav-journal", isHovering: true, isTouchDown: true)
            }
            .padding()
        }
        .background(BeamColor.Beam.swiftUI.opacity(0.1))
        Group {
            HStack {
                ToolbarButton(icon: "nav-journal")
                ToolbarButton(icon: "nav-journal", isHovering: true)
                ToolbarButton(icon: "nav-journal", isHovering: true, isTouchDown: true)
            }
            .padding()
        }.preferredColorScheme(.dark)
            .background(Color.black)
    }
}
