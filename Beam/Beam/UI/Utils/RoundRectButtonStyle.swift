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

    let pressedBg = Color("ToolbarButtonBackgroundOnColor")
    let hoverBg = Color("ToolbarButtonBackgroundOnColor")
    let emptyBg = Color(.displayP3, white: 1, opacity: 0)

    func bgColor(_ enabled: Bool, _ hover: Bool, _ pressed: Bool) -> Color {
        //print("color: isHovering: \(hover) pressed: \(pressed) isEnabled: \(enabled)")
        guard enabled else { return emptyBg }
        guard !pressed else { return pressedBg }
        return hover ? hoverBg : emptyBg
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .foregroundColor(bgColor(isEnabled, isHovering, isPressed))
            .onHover { h in
                self.isHovering = h
                //print("onHover: isHovering: \(self.isHovering) (\(h)) isEnabled: \(self.isEnabled)")
            }
            .frame(width: 33, height: 28, alignment: .center)
    }
}

struct RoundRectButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .background(RoundedRectangleDecoration(isPressed: configuration.isPressed))
            .frame(width: 33, height: 28, alignment: .center)
    }
}
