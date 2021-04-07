//
//  RoundRectButtonStyle.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct RoundedRectangleDecoration: View {
    @Environment(\.isEnabled) var isEnabled: Bool
    @State private var isHovering: Bool = false
    let size: CGFloat
    let isPressed: Bool

    private let pressedBg = BeamColor.Button.activeBackground.swiftUI
    private let emptyBg = BeamColor.Generic.transparent.swiftUI

    func bgColor(_ enabled: Bool, _ pressed: Bool) -> Color {
        return enabled && pressed ? pressedBg : emptyBg
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(bgColor(isEnabled, isPressed))
            .onHover { h in
                self.isHovering = h
            }
            .frame(width: size, height: size, alignment: .center)
    }
}

struct RoundRectButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled: Bool
    var size: CGFloat?
    var defaultSize: CGFloat = 26
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration
            .label
            .background(RoundedRectangleDecoration(size: size ?? defaultSize, isPressed: configuration.isPressed))
            .frame(width: size, height: size, alignment: .center)
    }
}
