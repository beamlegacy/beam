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

    @Environment(\.isEnabled) private var isEnabled: Bool
    @State var isHover = false
    var foregroundColor: Color {
        guard isEnabled else { return Color(.displayP3, white: 1, opacity: 0) }
        return isHover ? Color("ToolbarButtonBackgroundOnColor") : Color("ToolbarButtonBackgroundHoverColor")
    }
    public func makeBody(configuration: BorderedButtonStyle.Configuration) -> some View {
        return ZStack {
            RoundedRectangle(cornerRadius: _cornerRadius).foregroundColor(foregroundColor).frame(width: 33, height: 28, alignment: .center)
            configuration.label.foregroundColor(Color(isEnabled ? "ToolbarButtonIconColor" : "ToolbarButtonIconDisabledColor"))
        }
        .onTapGesture(count: 1) {
            configuration.trigger()
        }
        .onHover { h in
            isHover = h && isEnabled
        }
    }
}
