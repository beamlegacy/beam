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
            // - LongPress to have a minimumDuration before triggering touch down.
            //   (a trackpad tap is shorter than 0.01s, as opposed to a real click)
            // - Drag to detect touch up.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.01, maximumDistance: 0)
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
