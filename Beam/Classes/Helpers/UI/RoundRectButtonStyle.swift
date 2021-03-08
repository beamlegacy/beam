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
    @State var isHovering: Bool = false
    var isPressed: Bool

    private let pressedBg = Color(.toolbarButtonActiveBackgroundColor)
    private let emptyBg = Color(.transparent)

    func bgColor(_ enabled: Bool, _ pressed: Bool) -> Color {
        return enabled && pressed ? pressedBg : emptyBg
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(bgColor(isEnabled, isPressed))
            .onHover { h in
                self.isHovering = h
            }
            .frame(width: 26, height: 26, alignment: .center)
    }
}

struct RoundRectButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled: Bool

    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration
            .label
            .background(RoundedRectangleDecoration(isPressed: configuration.isPressed))
            .frame(width: 26, height: 26, alignment: .center)
    }
}
