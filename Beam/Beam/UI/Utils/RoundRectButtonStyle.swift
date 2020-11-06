//
//  RoundRectButtonStyle.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct RoundRectButtonStyle: PrimitiveButtonStyle {
    private var _cornerRadius = CGFloat(7)

    private enum ButtonGestureState {
        case inactive
        case pressing
        case outOfBounds

        var isPressed: Bool {
            switch self {
            case .pressing:
                return true
            default:
                return false
            }
        }
    }

    @GestureState private var dragState = ButtonGestureState.inactive

    @Environment(\.isEnabled) var isEnabled
    @State var isHover = false
    @State var isPressed = false
    func foregroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return Color(.displayP3, white: 1, opacity: 0) }
        if isPressed {
            return Color("ToolbarButtonBackgroundOnColor")
        }
        return isHover ? Color("ToolbarButtonBackgroundHoverColor") : Color.init(.displayP3, white: 1, opacity: 0)
    }
    public func makeBody(configuration: Self.Configuration) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0)
            .updating($dragState, body: { _, state, _ in
                state = isHover ? .pressing : .outOfBounds
            })
            .onChanged({ _ in
                withAnimation(.easeInOut(duration: 0.16)) {
                    self.isPressed = self.dragState.isPressed
                }
            })
            .onEnded { _ in
                print("onEnded (\(isPressed))")
                if self.isPressed {
                    configuration.trigger()
                }

                withAnimation(.easeInOut(duration: 0.16)) {
                    self.isPressed = self.dragState.isPressed
                }
            }

        return ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(foregroundColor(isPressed: isPressed))
                .frame(width: 33, height: 28, alignment: .center)

            configuration.label.foregroundColor(Color(isEnabled ? "ToolbarButtonIconColor" : "ToolbarButtonIconDisabledColor"))
        }
        .onHover { h in
            isHover = h && isEnabled
        }
        .highPriorityGesture(dragGesture, including: .gesture)
    }
}
