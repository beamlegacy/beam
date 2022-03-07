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

    static let customShadowPadding: CGFloat = 40
    private let strokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))
    private let shadowColor: BeamColor

    private(set) var didMove = false
    private var moveNotificationToken: NSObjectProtocol?

    private var _canBecomeKey: Bool
    private var _canBecomeMain: Bool
    private var _useBeamShadow: Bool

    init(canBecomeMain: Bool, canBecomeKey: Bool = true, useBeamShadow: Bool = false, lightBeamShadow: Bool = false) {
        _canBecomeKey = canBecomeKey
        _canBecomeMain = canBecomeMain
        _useBeamShadow = useBeamShadow
        shadowColor = lightBeamShadow ? .From(color: .black, alpha: 0.16) : .combining(lightColor: .From(color: .black, alpha: 0.16), darkColor: .From(color: .black, alpha: 0.7))
        super.init(contentRect: .zero, styleMask: [.fullSizeContentView, .borderless], backing: .buffered, defer: false)
    }

    func setOrigin(_ point: CGPoint, fromTopLeft: Bool = false) {
        if var originScreen = self.parent?.convertPoint(toScreen: point) {
            if _useBeamShadow {
                originScreen.y += fromTopLeft ? Self.customShadowPadding : -Self.customShadowPadding
                originScreen.x -= Self.customShadowPadding
            }

            if fromTopLeft {
                self.setFrameTopLeftPoint(originScreen)
            } else {
                self.setFrameOrigin(originScreen)
            }
        }
    }

    func setView<Content>(content: Content) where Content: View {
        self.contentView = NSHostingView(rootView: updateViewIfNeeded(content))
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

    override var hasShadow: Bool {
        get {
            if _useBeamShadow {
                return false
            }
            return super.hasShadow
        }

        set {
            if _useBeamShadow {
                super.hasShadow = false
            }
            super.hasShadow = newValue
        }
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

    private func updateViewIfNeeded<Content>(_ view: Content)  -> some View where Content: View {
        view.if(_useBeamShadow, transform: { $0.background(RoundedRectangle(cornerRadius: 10.0).stroke(strokeColor.swiftUI, lineWidth: 1)).shadow(color: self.shadowColor.swiftUI, radius: 15, x: 0, y: 12).padding(Self.customShadowPadding) })
    }
}
