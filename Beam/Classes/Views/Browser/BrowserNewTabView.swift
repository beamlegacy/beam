//
//  BrowserNewTabView.swift
//  Beam
//
//  Created by Remi Santos on 27/04/2021.
//

import SwiftUI

struct BrowserNewTabView: View {

    var action: (() -> Void)?
    @State private var isHovering = false
    @State private var isTouchDown = false

    private var buttonState: ButtonLabelState {
        guard !isTouchDown else { return .clicked }
        return isHovering ? .hovered : .normal
    }

    var body: some View {
        ButtonLabel(icon: "tabs-new",
                    state: buttonState,
                    customStyle: ButtonLabelStyle.tinyIconStyle,
                    action: action)
            .padding(.horizontal, BeamSpacing._100)
            .padding(.vertical, BeamSpacing._60)
            .frame(maxHeight: .infinity)
            .background(BeamColor.Nero.swiftUI
                            .overlay(Rectangle()
                                        .fill(BeamColor.BottomBar.shadow.swiftUI)
                                        .frame(height: 0.5),
                                     alignment: .top)
            )
            .onHover { isHovering = $0 }
            .onTouchDown { isTouchDown = $0 }
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                action?()
            })
    }
}
