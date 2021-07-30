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
        CustomPopoverPresenter.shared.dismissMenu()
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        CustomPopoverPresenter.shared.dismissMenu()
    }

    override func otherMouseDown(with event: NSEvent) {
        super.otherMouseDown(with: event)
        CustomPopoverPresenter.shared.dismissMenu()
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class CustomPopoverPresenter {
    static var shared = CustomPopoverPresenter()

    private var currentView: NSView?
    private var currentMenu: FormatterView?
    private var childWindow: NSWindow?
    private var parentWindow: NSWindow?

    private func createChildWindow(in parent: NSWindow, canOverflow: Bool) -> NSWindow {
        let windowRect = canOverflow ? parent.screen?.frame : parent.frame
        let window = ContextMenuWindow(contentRect: windowRect ?? parent.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        parent.addChildWindow(window, ordered: .above)
        childWindow = window
        parentWindow = parent
        return window
    }

    func dismissMenu(animated: Bool = true) {
        if animated {
            let menu = currentMenu
            menu?.animateOnDisappear(completionHandler: { [weak self] in
                guard menu == self?.currentMenu else { return }
                self?.dismissMenu(removeWindow: true)
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
        guard let view = fromView ?? AppDelegate.main.window?.contentView else { return }
        if currentMenu != nil {
            dismissMenu(removeWindow: true)
        }
        menu.frame = NSRect(origin: .zero, size: menu.idealSize)
        currentMenu = menu
        guard let parentWindow = view.window else {
            return
        }
        let window = createChildWindow(in: parentWindow, canOverflow: true)
        window.contentView?.addSubview(menu)

        var position = convertPointToScreen(atPoint, fromView: view, inWindow: parentWindow)
        position = window.convertPoint(fromScreen: position)
        position.y = max(0, position.y - menu.bounds.height)
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
        let childWindow = createChildWindow(in: parentWindow, canOverflow: false)
        childWindow.contentView = FlippedView()
        view.translatesAutoresizingMaskIntoConstraints = false
        childWindow.contentView?.addSubview(view)

        let position = view.convert(atPoint, from: parentView)
        view.setFrameOrigin(position)

        return childWindow
    }

    private func convertPointToScreen(_ point: CGPoint, fromView: NSView, inWindow: NSWindow) -> CGPoint {
        return inWindow.convertPoint(toScreen: fromView.convert(point, to: nil))
    }

    func presentAutoDismissingChildWindow() -> AutoDismissingWindow? {

        guard let mainWindow = AppDelegate.main.window else { return nil }

        let window = AutoDismissingWindow()
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear

        window.styleMask = [.fullSizeContentView, .borderless]

        mainWindow.addChildWindow(window, ordered: .above)
        return window
    }
}
