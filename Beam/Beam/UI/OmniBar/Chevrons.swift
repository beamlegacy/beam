//
//  File.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/10/2020.
//

import Foundation
import SwiftUI

struct Chevrons: View {
    @EnvironmentObject var state: BeamState

    var body: some View {
            HStack {
                Button(action: goBack) {
                    Symbol(name: "chevron.left")//.offset(x: 0, y: -0.5)
                }
                .buttonStyle(RoundRectButtonStyle())
//                .buttonStyle(BorderlessButtonStyle())
                .disabled(!state.canGoBack)

                Button(action: goForward) {
                    Symbol(name: "chevron.right")//.offset(x: 0, y: -0.5)
                }
                .buttonStyle(RoundRectButtonStyle())
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
