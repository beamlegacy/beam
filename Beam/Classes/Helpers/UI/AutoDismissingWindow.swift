//
//  AutoDismissingWindow.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 19/07/2021.
//

import AppKit
import SwiftUI

/// Use this class if you need a NSWindow that will close itself once it looses key status, if it hasn't been moved.
class AutoDismissingWindow: NSWindow {

    private var didMove = false
    private var moveNotificationToken: NSObjectProtocol?

    func setOrigin(_ point: CGPoint) {
        if let originScreen = self.parent?.convertPoint(toScreen: point) {
            self.setFrameOrigin(originScreen)
        }
    }

    func setView<Content>(content: Content) where Content: View {
        self.contentView = NSHostingView(rootView: content)
    }

    func setView<Content>(with view: Content, at origin: NSPoint) where Content: View {
        setView(content: view)
        setOrigin(origin)
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
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
}
