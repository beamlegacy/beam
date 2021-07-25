//
//  OverlayViewCenterViewModel.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import SwiftUI

class OverlayViewCenterViewModel: ObservableObject {

    @Published var show = false
    @Published var toastView: AnyView? {
        didSet {
            show.toggle()
        }
    }

    func present(text: String?, icon: String?) {
        toastView = AnyView(ToastTextIconView(text: text, icon: icon))
    }
}
