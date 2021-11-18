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

    private var iconColor: Color {
        isTouchDown || isHovering ? BeamColor.Niobium.swiftUI :
            BeamColor.LightStoneGray.swiftUI
    }

    var body: some View {
        Icon(name: "tool-new", size: 16, color: iconColor)
            .padding(.horizontal, BeamSpacing._100)
            .padding(.vertical, BeamSpacing._60)
            .frame(maxHeight: .infinity)
            .background(BrowserTabView.BackgroundView(isSelected: false, isHovering: isHovering))
            .onHover { isHovering = $0 }
            .onTouchDown { isTouchDown = $0 }
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                action?()
            })
    }
}
