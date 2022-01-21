//
//  ToolbarModeSwitcher.swift
//  Beam
//
//  Created by Remi Santos on 10/12/2021.
//

import SwiftUI
import BeamCore

struct ToolbarModeSwitcher: View {
    @Environment(\.isMainWindow) private var isMainWindow

    var modeWeb: Bool = false
    var tabsCount: Int = 0
    var action: (() -> Void)?

    @State private var showLottie: Bool = false
    @State private var isHovering = false
    private let defaultColor = BeamColor.LightStoneGray
    private let hoveringColor = BeamColor.Generic.text
    private let inactiveColor = BeamColor.ToolBar.buttonForegroundInactiveWindow
    private var foregroundColor: BeamColor {
        guard isMainWindow else {
            return inactiveColor
        }
        return isHovering ? hoveringColor : defaultColor
    }

    private var textTransition: AnyTransition {
        .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: 3)).animation(.easeInOut(duration: 0.1).delay(0.12))
                        .combined(with: .opacity.animation(.easeInOut(duration: 0.025).delay(0.12))),
                    removal: .animatableOffset(offset: CGSize(width: 0, height: -3)).animation(.easeInOut(duration: 0.6).delay(0.01))
                        .combined(with: .opacity.animation(.easeInOut(duration: 0.07).delay(0.09)))
        )
    }

    private func lottieView(name: String) -> some View {
        ZStack {
            LottieView(name: name, playing: true, color: (isMainWindow ? defaultColor : inactiveColor).nsColor, loopMode: .playOnce, speed: 2.5)
                .opacity(isHovering ? 0 : 1)
            LottieView(name: name, playing: true, color: hoveringColor.nsColor, loopMode: .playOnce, speed: 2.5)
                .opacity(isHovering ? 1 : 0)
        }
        .opacity(showLottie ? 1 : 0)
        .frame(width: 24, height: 24)
    }

    var body: some View {
        ZStack {
            ToolbarButton(icon: "transparent", action: action)
            ZStack {
                Group {
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
                    if !showLottie {
                        Icon(name: modeWeb ? "nav-pivot_web" : "nav-pivot_card", width: 24, color: foregroundColor.swiftUI)
                    }
                }
                .opacity(slotMachine.isVisible ? 0 : 1)
                .animation(BeamAnimation.easeInOut(duration: 0.1), value: slotMachine.isVisible)
                if slotMachine.isVisible {
                    SlotMachine(foregroundColor: foregroundColor.swiftUI)
                        .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.1)))
                }
            }
            .blendModeLightMultiplyDarkScreen()
            .allowsHitTesting(false)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { // wait for lottie first animation to be over
                showLottie = isMainWindow
            }
        }
        .onChange(of: isMainWindow) { newValue in
            if !newValue {
                showLottie = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { // wait for lottie first animation to be over
                    showLottie = true
                }
            }
        }
        .onChange(of: modeWeb) { _ in
            slotMachine.receivedToggle()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(modeWeb ? "\(tabsCount)" : "note")
        .accessibilityIdentifier(modeWeb ? "pivot-web" : "pivot-card")
    }

    @StateObject var slotMachine = SlotMachineModel()
    class SlotMachineModel: ObservableObject {

        var numberOfQuickToggle: Int = 0
        var lastToggle: Date = .init()

        @Published var isVisible = false
        func receivedToggle() {
            guard !isVisible else { return }
            let interval = -lastToggle.timeIntervalSinceNow
            if interval < 0.5 {
                numberOfQuickToggle += 1
            } else {
                numberOfQuickToggle = 1
            }
            lastToggle = .init()
            if numberOfQuickToggle >= 5 {
                isVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
                    self?.isVisible = false
                }
            }
        }
    }
}

private struct SlotMachine: View {

    var foregroundColor: Color
    private let slotSpacing: CGFloat = 6
    private let slotHeight: CGFloat = 10
    private let slotContainerHeight: CGFloat = 13
    private struct Slot: Identifiable {
        var id = UUID()
        var icon: String
        init(_ icon: String) {
            self.icon = icon
        }
    }

    @State private var slots = [
        Slot("nav-pivot-slot_moo"),
        Slot("nav-pivot-slot_bomb"),
        Slot("nav-pivot-slot_cmd"),
        Slot("nav-pivot-slot_document"),
        Slot("nav-pivot-slot_happy"),
        Slot("nav-pivot-slot_trash"),
        Slot("nav-pivot-slot_volume"),
        Slot("nav-pivot-slot_wait"),
        Slot("nav-pivot-slot_moo"),
        Slot("nav-pivot-slot_bomb"),
        Slot("nav-pivot-slot_cmd"),
        Slot("nav-pivot-slot_document"),
        Slot("nav-pivot-slot_happy"),
        Slot("nav-pivot-slot_trash"),
        Slot("nav-pivot-slot_volume"),
        Slot("nav-pivot-slot_wait")
    ]
    @State private var atEndOfRoulette = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: slotSpacing) {
                ForEach(slots) { slot in
                    Icon(name: slot.icon, width: slotHeight, color: foregroundColor)
                }
            }
            .offset(x: 0, y: (slotContainerHeight - slotHeight) / 2)
            .offset(x: 0, y: atEndOfRoulette ? 0 : CGFloat(slots.count-1) * -(slotHeight+slotSpacing))
        }
        .frame(width: 18, height: slotContainerHeight, alignment: .top)
        .clipped()
        .overlay(Icon(name: "nav-pivot_slot_border", width: 24, color: foregroundColor))
        .onAppear {
            if let randomElement = slots.randomElement() {
                slots.insert(randomElement, at: 0)
            }
            DispatchQueue.main.async {
                withAnimation(BeamAnimation.easeInOut(duration: 2)) {
                    atEndOfRoulette = true
                }
            }
        }
        .onDisappear {
            atEndOfRoulette = false
        }
    }
}

struct ToolbarModeSwitcher_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                ToolbarModeSwitcher(modeWeb: false)
                ToolbarModeSwitcher(modeWeb: true, tabsCount: 3)
                ToolbarModeSwitcher(modeWeb: true, tabsCount: 33)
                ToolbarModeSwitcher(modeWeb: true, tabsCount: 123)
            }
            .padding()
        }
    }
}
