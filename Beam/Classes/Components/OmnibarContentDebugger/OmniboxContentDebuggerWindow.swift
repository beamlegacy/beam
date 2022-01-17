//
//  OmniboxContentDebuggerWindow.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/01/2022.
//

import Foundation
import SwiftUI
import Cocoa
import Combine

class OmniboxContentDebuggerWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "Omnibox Content Debugger"

        let omniboxContentDebuggerView = OmniboxContentDebuggerView()
        contentView = BeamHostingView(rootView: omniboxContentDebuggerView)
        isMovableByWindowBackground = false
        delegate = self
    }

    deinit {
        AppDelegate.main.omniboxContentDebuggerWindow = nil
    }
}
