//
//  ClickCatchingView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 13/07/2021.
//

import SwiftUI

struct ClickCatchingView: NSViewRepresentable {

    private class ClickCatchingNSView: NSView {

        var onTap: ((NSEvent) -> Void)?
        var onRightTap: ((NSEvent) -> Void)?
        var onDoubleTap: ((NSEvent) -> Void)?

        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            if event.clickCount == 2 {
                onDoubleTap?(event)
            } else {
                onTap?(event)
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
            onRightTap?(event)
        }
    }

    var onTap: ((NSEvent) -> Void)?
    var onRightTap: ((NSEvent) -> Void)?
    var onDoubleTap: ((NSEvent) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = ClickCatchingNSView()
        view.onTap = onTap
        view.onRightTap = onRightTap
        view.onDoubleTap = onDoubleTap
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ClickCatchingNSView else { return }
        view.onTap = onTap
        view.onRightTap = onRightTap
        view.onDoubleTap = onDoubleTap
    }
}
