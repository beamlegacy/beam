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
        var firstResponder: Bool

        private var firstResponderSet = false

        override var acceptsFirstResponder: Bool { true }

        override init(frame frameRect: NSRect) {
            self.onKeyDown = nil
            self.handledKeyCodes = []
            self.firstResponder = false
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

        override func mouseDown(with event: NSEvent) {
            self.window?.makeFirstResponder(self)
        }

        func askForFirstResponder() {
            guard let window = self.window else { return }
            if !firstResponderSet {
                firstResponderSet = window.makeFirstResponder(self)
            }
        }
    }

    /// Provide handled keycodes to prevent the the super call.
    /// onKeyDown will only be called for the handled keys
    let handledKeyCodes: [KeyCode]

    ///Make the view firstResponder on init
    var firstResponder: Bool

    ///Handle the keyDown for provided keyCodes
    let onKeyDown: ((NSEvent) -> Void)

    init(handledKeyCodes: [KeyCode], firstResponder: Bool = false, onKeyDown: (@escaping (NSEvent) -> Void)) {
        self.handledKeyCodes = handledKeyCodes
        self.firstResponder = firstResponder
        self.onKeyDown = onKeyDown
    }

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        view.handledKeyCodes = handledKeyCodes
        view.firstResponder = firstResponder

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if firstResponder {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                (nsView as? KeyView)?.askForFirstResponder()
            }
        }
    }
}
