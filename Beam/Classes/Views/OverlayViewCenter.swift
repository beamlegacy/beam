//
//  OverlayViewCenter.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import SwiftUI

struct OverlayViewCenter: View {
    @ObservedObject var viewModel: OverlayViewCenterViewModel

    var body: some View {
        ZStack {
        }.toast(isPresented: $viewModel.show) {
            viewModel.toastView
        }.toastStyle(BottomTraillingToastStyle())
    }
}
