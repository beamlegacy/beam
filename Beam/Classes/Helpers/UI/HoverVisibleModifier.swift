//
//  HoverVisibleModifier.swift
//  Beam
//
//  Created by Remi Santos on 16/06/2021.
//

import SwiftUI

extension View {
    /**
     * Equivalent of `onHover` that does not trigger hovering when the view appear under the mouse
     * - Parameter action: The action to perform whenever the pointer enters or leave the view's frame
     */
    func onHoverOnceVisible(perform action:@escaping (Bool) -> Void) -> some View {
        self.modifier(HoverOnceVisibleModifier(action: action))
    }
}

private struct HoverOnceVisibleModifier: ViewModifier {
    static let timeBeforeHover: TimeInterval = 0.25

    var action: ((Bool) -> Void)?
    @State private var appearTime: Date?
    @State private var hoverEnabled = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTime = Date()
            }
            .onHover { hovering in
                if hovering {
                    if let appearTime = appearTime {
                        let timeSinceAppear = Date().timeIntervalSince(appearTime)
                        hoverEnabled = timeSinceAppear >= Self.timeBeforeHover
                    }
                    if hoverEnabled {
                        action?(hovering)
                    }
                } else {
                    action?(hovering)
                }
            }
    }
}
