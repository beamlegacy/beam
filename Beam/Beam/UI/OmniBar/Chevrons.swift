//
//  File.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct ChevronButtonStyle: PrimitiveButtonStyle {
    private var _cornerRadius = CGFloat(7)

    @Environment(\.isEnabled) private var isEnabled: Bool
    @State var isHover = false
    var foregroundColor = Color(.displayP3, white: 0, opacity: 0)
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

struct Chevrons: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
            HStack {
                Button(action: goBack) {
                    Symbol(name: "chevron.left")//.offset(x: 0, y: -0.5)
                }
                .buttonStyle(ChevronButtonStyle())
//                .buttonStyle(BorderlessButtonStyle())
                .disabled(!state.canGoBack)

                Button(action: goForward) {
                    Symbol(name: "chevron.right")//.offset(x: 0, y: -0.5)
                }
                .buttonStyle(ChevronButtonStyle())
//                .buttonStyle(BorderlessButtonStyle())
                .disabled(!state.canGoForward)
                .padding(.leading, 9)
            }
            .padding(.leading, 18)
    //        .offset(x: 0, y: -9)
    }

    func goBack() {
        state.goBack()
    }

    func goForward() {
        state.goForward()
    }

}
