//
//  PopoverWindow.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 19/07/2021.
//

import AppKit
import SwiftUI

/// Use this class if you need a NSWindow that can close itself once it looses key status, if it hasn't been moved.
class PopoverWindow: NSWindow {

    private(set) var didMove = false
    private var moveNotificationToken: NSObjectProtocol?

    private var _canBecomeKey: Bool
    private var _canBecomeMain: Bool
    init(canBecomeKey: Bool = true, canBecomeMain: Bool) {
        _canBecomeKey = canBecomeKey
        _canBecomeMain = canBecomeMain
        super.init(contentRect: .zero, styleMask: [.fullSizeContentView, .borderless], backing: .buffered, defer: false)
    }

    override func setContentSize(_ size: NSSize) {
        super.setContentSize(size)
    }

    func setOrigin(_ point: CGPoint, fromTopLeft: Bool = false) {
        if let originScreen = self.parent?.convertPoint(toScreen: point) {
            if fromTopLeft {
                self.setFrameTopLeftPoint(originScreen)
            } else {
                self.setFrameOrigin(originScreen)
            }
        }
    }

    func setView<Content>(content: Content) where Content: View {
        self.contentView = NSHostingView(rootView: content)
    }

    func setView<Content>(with view: Content, at origin: NSPoint, fromTopLeft: Bool = false) where Content: View {
        if fromTopLeft && self.frame.size == .zero {
            // to place top left corner we need a minimum width, otherwise the window will center to that location when resized.
            self.setContentSize(CGSize(width: 10, height: 10))
        }
        setView(content: view)
        setOrigin(origin, fromTopLeft: fromTopLeft)
    }

    func setView(with view: NSView, at origin: NSPoint, fromTopLeft: Bool = false) {
        self.contentView = view
        setOrigin(origin, fromTopLeft: fromTopLeft)
    }

    override var canBecomeKey: Bool {
        return _canBecomeKey
    }

    override var canBecomeMain: Bool {
        return _canBecomeMain
    }

    override func becomeMain() {
        super.becomeMain()
    }

    override func becomeKey() {
        super.becomeKey()
    }

    override func resignMain() {
        super.resignMain()
        if !didMove {
            self.close()
            NotificationCenter.default.removeObserver(self, name: .init("NSWindowDidMoveNotification"), object: nil)
        }
    }

    override func resignKey() {
        if !didMove {
            self.close()
            NotificationCenter.default.removeObserver(self, name: .init("NSWindowDidMoveNotification"), object: nil)
        }
        super.resignKey()
    }

    override func resignFirstResponder() -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        moveNotificationToken = addMoveObserver()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        removeMoveObserver()
    }

    private func addMoveObserver() -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .init("NSWindowDidMoveNotification"), object: self, queue: .main) { [weak self] _ in
            self?.didMove = true
        }
    }

    private func removeMoveObserver() {
        if let moveNotificationToken = moveNotificationToken {
            NotificationCenter.default.removeObserver(moveNotificationToken)
            self.moveNotificationToken = nil
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape.rawValue {
            self.close()
        } else {
            super.keyDown(with: event)
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(performClose(_:)) {
            return true
        } else {
            return super.validateMenuItem(menuItem)
        }
    }

    override func performClose(_ sender: Any?) {
        self.close()
    }
}
