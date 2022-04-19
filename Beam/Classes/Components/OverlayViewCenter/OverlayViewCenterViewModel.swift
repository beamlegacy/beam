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

    @Published var showTooltip: String?
    /// global position in window
    @Published var tooltipPosition: CGPoint = .zero
    private var tooltipCancellable: DispatchWorkItem?

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

    func presentModal<V>(_ view: V) where V: View {
        modalView = AnyView(view)
    }

    /// Present tooltip of text for few seconds
    ///
    /// at point should be in TopLeft coordinate system
    func presentTooltip(text: String?, at point: CGPoint) {
        tooltipCancellable?.cancel()
        guard showTooltip == nil else {
            // dismiss current tooltip then retry to present
            showTooltip = nil
            let workItem = DispatchWorkItem { [weak self] in
                self?.presentTooltip(text: text, at: point)
            }
            tooltipCancellable = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300), execute: workItem)
            return
        }
        showTooltip = text
        tooltipPosition = point
        let workItem = DispatchWorkItem { [weak self] in
            self?.showTooltip = nil
        }
        tooltipCancellable = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500), execute: workItem)
    }

    func dismissCurrentModal() {
        modalView = nil
    }
}
