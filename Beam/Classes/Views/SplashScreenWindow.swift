//
//  SplashScreenWindow.swift
//  Beam
//
//  Created by Remi Santos on 11/07/2022.
//

import SwiftUI
import BeamCore

class SplashScreenWindow: NSWindow {

    var text: String = "" {
        didSet {
            splashScreenViewModel.message = text
            tick()
        }
    }

    private var nextReport = BeamDate.now
    private var splashScreenViewModel = SplashScreenView.SplashScreenViewModel()
    private let hostingView: BeamHostingView<SplashScreenView>

    init() {
        self.splashScreenViewModel.message = text
        let contentView = BeamHostingView(rootView: SplashScreenView(model: splashScreenViewModel))
        self.hostingView = contentView
        super.init(contentRect: CGRect(x: 0, y: 0, width: 512, height: 600),
                   styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        self.contentView = contentView
        isReleasedWhenClosed = false
        level = .floating
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        let customToolbar = NSToolbar()
        customToolbar.showsBaselineSeparator = false
        toolbar = customToolbar
        collectionBehavior = .fullScreenNone
        standardWindowButton(.closeButton)?.isEnabled = false
    }

    func presentWindow() {
        center()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        tick()
    }

    func tick() {
        let now = BeamDate.now
        if nextReport < now {
            RunLoop.main.run(mode: .modalPanel, before: BeamDate.now.addingTimeInterval(0.01))
            nextReport = BeamDate.now.addingTimeInterval(0.2)
        }
    }
}

private struct SplashScreenView: View {

    @ObservedObject var model: SplashScreenViewModel
    private let isDevelop = Configuration.branchType == .develop

    var body: some View {
        OnboardingView.LoadingView(subtitle: "Upgrading your database", additionalDetails: isDevelop ? "(\(model.message))" : nil)
            .frame(width: 512, height: 562)
            .background(BeamColor.Generic.background.swiftUI.edgesIgnoringSafeArea(.all))
    }
}

extension SplashScreenView {
    class SplashScreenViewModel: ObservableObject {
        @Published var message: String = ""

        init() { }
    }
}
