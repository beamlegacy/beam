//
//  OmniboxV2ToolbarSwitcher.swift
//  Beam
//
//  Created by Remi Santos on 10/12/2021.
//

import SwiftUI

struct OmniboxV2ToolbarSwitcher: View {
    var modeWeb: Bool = false
    var tabsCount: Int = 0
    var action: (() -> Void)?

    @State private var isHovering = false
    private let defaultColor = BeamColor.LightStoneGray
    private let hoveringColor = BeamColor.Generic.text
    private var foregroundColor: BeamColor {
        isHovering ? hoveringColor : defaultColor
    }

    private var textTransition: AnyTransition {
        .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: 3)).animation(.easeInOut(duration: 0.1).delay(0.3))
                        .combined(with: .opacity.animation(.easeInOut(duration: 0.07).delay(0.3))),
                    removal: .animatableOffset(offset: CGSize(width: 0, height: -3)).animation(.easeInOut(duration: 0.11).delay(0.02))
                        .combined(with: .opacity.animation(.easeInOut(duration: 0.07).delay(0.09)))
        )
    }

    private func lottieView(name: String) -> some View {
        ZStack {
            LottieView(name: name, playing: true, color: defaultColor.nsColor, loopMode: .playOnce, speed: 1)
                .opacity(isHovering ? 0 : 1)
            LottieView(name: name, playing: true, color: hoveringColor.nsColor, loopMode: .playOnce, speed: 1)
                .opacity(isHovering ? 1 : 0)
        }
    }
    var body: some View {
        ZStack {
            OmniboxV2ToolbarButton(icon: "transparent", action: action)
            ZStack {
                if modeWeb {
                    lottieView(name: "nav-pivot_card")
                    if tabsCount >= 100 {
                        Icon(name: "nav-pivot-infinite", size: CGSize(width: 12, height: 6), color: foregroundColor.swiftUI)
                            .transition(textTransition)
                    } else {
                        Text("\(tabsCount)")
                            .font(BeamFont.semibold(size: 9).swiftUI)
                            .foregroundColor(foregroundColor.swiftUI)
                            .transition(textTransition)
                            .offset(x: 0, y: -0.5)
                    }
                } else {
                    lottieView(name: "nav-pivot_web")
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(modeWeb ? "\(tabsCount)" : "card")
        .accessibilityIdentifier(modeWeb ? "pivot-web" : "pivot-card")
    }
}

struct OmniboxV2ToolbarSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                OmniboxV2ToolbarSwitcher(modeWeb: false)
                OmniboxV2ToolbarSwitcher(modeWeb: true, tabsCount: 3)
                OmniboxV2ToolbarSwitcher(modeWeb: true, tabsCount: 33)
                OmniboxV2ToolbarSwitcher(modeWeb: true, tabsCount: 123)
            }
            .padding()
        }
    }
}
