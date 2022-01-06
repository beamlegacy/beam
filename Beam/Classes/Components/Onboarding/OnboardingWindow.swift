//
//  OnboardingWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/12/2021.
//

import Foundation

class OnboardingWindow: NSWindow, NSWindowDelegate {
    override var isResizable: Bool { false }

    init(contentRect: NSRect, model: OnboardingManager) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)

        let onboardingView = OnboardingView(model: model)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        contentView = BeamHostingView(rootView: onboardingView)
        isMovableByWindowBackground = false
        delegate = self
    }
}
