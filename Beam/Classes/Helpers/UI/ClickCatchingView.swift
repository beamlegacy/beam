//
//  ClickCatchingView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 13/07/2021.
//

import SwiftUI

struct ClickCatchingView: NSViewRepresentable {
    /// sent on mouse up
    var onTap: ((NSEvent) -> Void)?

    /// sent on mouse down
    var onTapStarted: ((NSEvent) -> Void)?

    /// sent on right mouse up, or on control+mouse down
    var onRightTap: ((NSEvent) -> Void)?

    /// sent on 2nd click mouse up
    var onDoubleTap: ((NSEvent) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ClickCatchingNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
    }

    private class ClickCatchingNSView: NSView {
        weak var delegate: ClickCatchingNSViewDelegate?

        override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control {
                delegate?.viewDidClick(ofType: .rightClickUp, withEvent: event)
            } else {
                delegate?.viewDidClick(ofType: .clickDown, withEvent: event)
            }
        }

        override func mouseUp(with event: NSEvent) {
            super.mouseUp(with: event)
            if event.clickCount == 2 {
                delegate?.viewDidClick(ofType: .doubleClickUp, withEvent: event)
            } else if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control {
                // event sent on mouse down
            } else {
                delegate?.viewDidClick(ofType: .clickUp, withEvent: event)
            }
        }

        override func rightMouseUp(with event: NSEvent) {
            super.rightMouseUp(with: event)
            delegate?.viewDidClick(ofType: .rightClickUp, withEvent: event)
        }
    }

    class Coordinator: ClickCatchingNSViewDelegate {
        var parent: ClickCatchingView
        init(parent: ClickCatchingView) {
            self.parent = parent
        }

        fileprivate func viewDidClick(ofType type: ClickType, withEvent event: NSEvent) {
            switch type {
            case .clickDown:
                parent.onTapStarted?(event)
            case .clickUp:
                parent.onTap?(event)
            case .doubleClickUp:
                parent.onDoubleTap?(event)
            case .rightClickDown, .rightClickUp:
                parent.onRightTap?(event)
            }
        }
    }
}

private enum ClickType {
    case clickDown, clickUp, doubleClickUp, rightClickDown, rightClickUp
}

private protocol ClickCatchingNSViewDelegate: AnyObject {
    func viewDidClick(ofType type: ClickType, withEvent event: NSEvent)
}
