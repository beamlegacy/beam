//
//  SimpleHostingWindow.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 15/04/2022.
//

import Foundation
import SwiftUI

class SimpleHostingWindow: NSWindow {

    init(rect: CGRect, styleMask: NSWindow.StyleMask) {
        super.init(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)

        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
    }

    func setView<Content>(content: Content) where Content: View {
        self.contentView = NSHostingView(rootView: content)
    }
}
