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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onTouchDown?(true)
                    }
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
