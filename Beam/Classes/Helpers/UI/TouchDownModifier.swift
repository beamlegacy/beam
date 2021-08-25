//
//  TouchDownModifier.swift
//  Beam
//
//  Created by Remi Santos on 10/03/2021.
//

import SwiftUI

struct TouchDownModifier: ViewModifier {
    var onTouchDown: ((Bool) -> Void)?
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            // Combining LongPress & Drag gestures
            // - LongPress to control the minimumDuration before triggering touch down.
            // - Drag to detect touch up.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0, maximumDistance: 0)
                    .onEnded { _ in
                        onTouchDown?(true)
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        onTouchDown?(false)
                    }
            )
    }
}

extension View {
    func onTouchDown(_ handler:@escaping (Bool) -> Void) -> some View {
        self.modifier(TouchDownModifier(onTouchDown: handler))
    }
}
