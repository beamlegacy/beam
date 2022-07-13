//
//  TabCapsule.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 09/06/2022.
//

import SwiftUI
import BeamCore

struct TabCapsule: View {
    let color: Color

    @State private var isHovered: Bool = false
    @State private var isClicked: Bool = false

    var body: some View {
        Capsule()
            .foregroundColor(foregroundColor)
            .blendModeLightMultiplyDarkScreen()
            .frame(height: 3)
            .frame(minWidth: isHovered ? 12.0 : 2.0)
            .padding(.top, 3)
            .padding(.bottom, 6)
            .padding(.horizontal, 1)
            .onHover { h in
                isHovered = h
            }
            .onTouchDown({ touchDown in
                isClicked = touchDown
            })
            .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    private var foregroundColor: Color {
        if isClicked {
            return color.opacity(1)
        } else if isHovered {
            return color.opacity(0.9)
        } else {
            return color.opacity(0.6)
        }
    }
}

struct TabCapsule_Previews: PreviewProvider {
    static var previews: some View {
        TabCapsule(color: .orange)
    }
}
