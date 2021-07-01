//
//  KeyEventHandlingView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 30/06/2021.
//

import SwiftUI

struct KeyEventHandlingView: NSViewRepresentable {
    private class KeyView: NSView {

        var onKeyDown: ((NSEvent) -> Void)?
        var handledKeyCodes: [KeyCode]

        override var acceptsFirstResponder: Bool { true }

        override init(frame frameRect: NSRect) {
            self.onKeyDown = nil
            self.handledKeyCodes = []
            super.init(frame: frameRect)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func keyDown(with event: NSEvent) {
            if handledKeyCodes.map({$0.rawValue}).contains(event.keyCode) {
                onKeyDown?(event)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    let onKeyDown: ((NSEvent) -> Void)

    /// Provide handled keycodes to prevent the the super call.
    /// onKeyDown will only be called for the handled keys
    let handledKeyCodes: [KeyCode]

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        view.handledKeyCodes = handledKeyCodes
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}
