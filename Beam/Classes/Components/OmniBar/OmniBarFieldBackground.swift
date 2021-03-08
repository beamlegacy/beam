//
//  OmniBarFieldBackground.swift
//  Beam
//
//  Created by Remi Santos on 04/03/2021.
//

import SwiftUI

struct OmniBarFieldBackground: View {
    var isEditing = false

    @State private var isHoveringBox = false
    private let boxCornerRadius: CGFloat = 6
    private var boxHeight: CGFloat {
        return isEditing ? 40 : 32
    }
    private var shadowOpacity: Double {
        return isEditing ? 0.1 : (isHoveringBox ? 0.05 : 0)
    }
    private var shadowRadius: CGFloat {
        return isEditing ? 12 : 6
    }
    private var shadowOffsetY: CGFloat {
        return isEditing ? 4 : 2
    }
    private let animationDuration = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: boxCornerRadius)
            .fill(Color(.editorBackgroundColor))
            .animation(.timingCurve(0.42, 0.0, 0.58, 1.0, duration: animationDuration))
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0.0, y: shadowOffsetY)
            .animation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: animationDuration))
            .frame(height: boxHeight)
            .onHover(perform: { hovering in
                isHoveringBox = hovering
            })
    }
}
