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
        HStack(spacing: 0) {
                Button(action: goBack) {
                    Symbol(name: "chevron.left")
                }
                .buttonStyle(RoundRectButtonStyle())
                .disabled(!state.canGoBack)

                Button(action: goForward) {
                    Symbol(name: "chevron.right")
                }
                .buttonStyle(RoundRectButtonStyle())
                .disabled(!state.canGoForward)
            }
            .padding(.leading, 18)
    }

    func goBack() {
        state.goBack()
    }

    func goForward() {
        state.goForward()
    }

}
