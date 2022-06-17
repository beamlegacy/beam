//
//  ClickCatchingView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 13/07/2021.
//

import SwiftUI

struct ClickCatchingView: NSViewRepresentable {

    var onTap: ((NSEvent) -> Void)?
    var onRightTap: ((NSEvent) -> Void)?
    var onDoubleTap: ((NSEvent) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ClickCatchingNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { }

    private class ClickCatchingNSView: NSView {
        weak var delegate: ClickCatchingNSViewDelegate?

        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            if event.clickCount == 2 {
                delegate?.viewDidClick(ofType: .doubleClick, withEvent: event)
            } else if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control {
                delegate?.viewDidClick(ofType: .rightClick, withEvent: event)
            } else {
                delegate?.viewDidClick(ofType: .click, withEvent: event)
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            super.rightMouseDown(with: event)
            delegate?.viewDidClick(ofType: .rightClick, withEvent: event)
        }
    }

    class Coordinator: ClickCatchingNSViewDelegate {
        let parent: ClickCatchingView
        init(parent: ClickCatchingView) {
            self.parent = parent
        }

        fileprivate func viewDidClick(ofType type: ClickType, withEvent event: NSEvent) {
            switch type {
            case .click:
                parent.onTap?(event)
            case .doubleClick:
                parent.onDoubleTap?(event)
            case .rightClick:
                parent.onRightTap?(event)
            }
        }
    }
}

private enum ClickType {
    case click, doubleClick, rightClick
}

private protocol ClickCatchingNSViewDelegate: AnyObject {
    func viewDidClick(ofType type: ClickType, withEvent event: NSEvent)
}
