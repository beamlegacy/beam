//
//  ContextMenuPresenter.swift
//  Beam
//
//  Created by Remi Santos on 23/03/2021.
//

import Foundation

private class ContextMenuWindow: NSWindow {

    override var acceptsFirstResponder: Bool {
        return true
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        ContextMenuPresenter.shared.dismissMenu()
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        ContextMenuPresenter.shared.dismissMenu()
    }

    override func otherMouseDown(with event: NSEvent) {
        super.otherMouseDown(with: event)
        ContextMenuPresenter.shared.dismissMenu()
    }
}

class ContextMenuPresenter {
    static var shared = ContextMenuPresenter()

    private var currentMenu: FormatterView?
    private var childWindow: NSWindow?
    private var parentWindow: NSWindow?

    private let windowInset: CGFloat = 0
    private func createChildWindow(for frame: NSRect, in parent: NSWindow) -> NSWindow {
        var windowRect = parent.frame// frame.insetBy(dx: -windowInset, dy: -windowInset)
        windowRect.origin = parent.frame.insetBy(dx: windowInset, dy: windowInset).origin
        let window = ContextMenuWindow(contentRect: windowRect, styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        parent.addChildWindow(window, ordered: .above)
        childWindow = window
        parentWindow = parent
        return window
    }

    func dismissMenu() {
        dismissMenu(removeWindow: true)
    }

    private func dismissMenu(removeWindow: Bool = false) {
        if let childWindow = childWindow, let parent = parentWindow, removeWindow {
            childWindow.setIsVisible(false)
            parent.removeChildWindow(childWindow)
            self.parentWindow = nil
            self.childWindow = nil
        }
        currentMenu?.removeFromSuperview()
    }

    func presentMenu(_ menu: FormatterView, from view: NSView, atPoint: CGPoint) {

        if currentMenu != nil {
            dismissMenu(removeWindow: true)
        }
        currentMenu = menu
        guard let parentWindow = view.window else {
            return
        }
        let window = createChildWindow(for: menu.frame, in: parentWindow)
        window.contentView?.addSubview(menu)

        var position = view.convert(atPoint, to: window.contentView!)
        position.y -= menu.bounds.height
        menu.setFrameOrigin(position)
    }
}
