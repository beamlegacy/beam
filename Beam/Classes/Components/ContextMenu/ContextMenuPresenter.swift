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

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class ContextMenuPresenter {
    static var shared = ContextMenuPresenter()

    private var currentView: NSView?
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

    func dismissMenu(animated: Bool = true) {
        if animated {
            currentMenu?.animateOnDisappear(completionHandler: {
                self.dismissMenu(removeWindow: true)
            })
            if currentView != nil && currentMenu == nil {
                dismissMenu(removeWindow: true)
            }
        } else {
            dismissMenu(removeWindow: true)
        }
    }

    private func dismissMenu(removeWindow: Bool = false) {
        if let childWindow = childWindow, let parent = parentWindow, removeWindow {
            childWindow.setIsVisible(false)
            parent.removeChildWindow(childWindow)
            self.parentWindow = nil
            self.childWindow = nil
        }
        currentMenu?.removeFromSuperview()
        currentView?.removeFromSuperview()
    }

    func presentMenu(_ menu: FormatterView, atPoint: CGPoint, from fromView: NSView? = nil, animated: Bool = true) {
        guard let view = fromView ?? AppDelegate.main.window.contentView else { return }
        if currentMenu != nil {
            dismissMenu(removeWindow: true)
        }
        let idealSize = menu.idealSize
        menu.frame = NSRect(x: 0, y: 0, width: idealSize.width, height: idealSize.height)
        currentMenu = menu
        guard let parentWindow = view.window else {
            return
        }
        let window = createChildWindow(for: menu.frame, in: parentWindow)
        window.contentView?.addSubview(menu)

        var position = view.convert(atPoint, to: window.contentView!)
        position.y -= menu.bounds.height
        menu.setFrameOrigin(position)

        if animated {
            DispatchQueue.main.async {
                menu.animateOnAppear()
            }
        }
    }

    func present(view: NSView, from parentView: NSView, atPoint: CGPoint) -> NSWindow? {
        if currentView != nil {
            dismissMenu(removeWindow: true)
        }
        currentView = view
        guard let parentWindow = parentView.window else { return nil }
        let childWindow = createChildWindow(for: view.frame, in: parentWindow)
        childWindow.contentView = FlippedView()
        view.translatesAutoresizingMaskIntoConstraints = false
        childWindow.contentView?.addSubview(view)

        let position = view.convert(atPoint, from: parentView)
        view.setFrameOrigin(position)

        return childWindow
    }
}
