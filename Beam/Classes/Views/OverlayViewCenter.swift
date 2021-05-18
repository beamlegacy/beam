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

    var body: some View {
        ZStack {
        }.toast(isPresented: $state.overlayViewModel.show) {
            state.overlayViewModel.credentialsToast
        }.toastStyle(BottomTraillingToastStyle())
    }
}
