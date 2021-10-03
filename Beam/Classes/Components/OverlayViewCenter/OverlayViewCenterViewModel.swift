//
//  OverlayViewCenterViewModel.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import SwiftUI

class OverlayViewCenterViewModel: ObservableObject {

    @Published var showModal = false
    @Published var modalView: AnyView? {
        didSet {
            showModal.toggle()
        }
    }

    @Published var showToast = false
    @Published var toastStyle: AnyToastStyle?
    @Published var toastView: AnyView? {
        didSet {
            showToast.toggle()
        }
    }

    func presentToast(text: String?, icon: String? = nil, alignment: Alignment = .bottomTrailing) {
        if alignment == .bottomLeading {
            toastStyle = AnyToastStyle(BottomLeadingToastStyle())
        } else if alignment == .bottomTrailing {
            toastStyle = AnyToastStyle(BottomTrailingToastStyle())
        } else {
            toastStyle = nil // default
        }
        toastView = AnyView(ToastTextIconView(text: text, icon: icon))
    }
}
