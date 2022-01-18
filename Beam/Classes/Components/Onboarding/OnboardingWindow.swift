//
//  OnboardingWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/12/2021.
//

import Foundation

class OnboardingWindow: NSWindow, NSWindowDelegate {
    override var isResizable: Bool { false }

    weak var model: OnboardingManager?

    init(model: OnboardingManager) {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 512, height: 600),
                   styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)

        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        let customToolbar = NSToolbar()
        customToolbar.showsBaselineSeparator = false
        toolbar = customToolbar
        collectionBehavior = .fullScreenNone
        isMovableByWindowBackground = false

        let button = standardWindowButton(.zoomButton)
        button?.isEnabled = false

        self.model = model
        let onboardingView = OnboardingView(model: model)
        contentView = BeamHostingView(rootView: onboardingView)

        delegate = self
    }

    override func close() {
        super.close()
        model?.windowDidClose()
    }
}
