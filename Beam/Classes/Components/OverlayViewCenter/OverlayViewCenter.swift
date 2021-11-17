//
//  OverlayViewCenter.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import SwiftUI

struct OverlayViewCenter: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var viewModel: OverlayViewCenterViewModel

    var body: some View {
        ZStack {
            if viewModel.showModal, let modalView = viewModel.modalView {
                ZStack {
                    modalView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BeamColor.Nero.swiftUI.opacity(0.4).onTapGesture {
                    viewModel.modalView = nil
                })
                .transition(AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.3)))
            }
            ZStack {}
                .toast(isPresented: $viewModel.showToast) {
                    viewModel.toastView
                }
                .toastStyle(
                    viewModel.toastStyle ?? AnyToastStyle(BottomTrailingToastStyle())
                )
                .padding(.bottom, state.mode != .web ? 15 : 0)
        }
    }
}
