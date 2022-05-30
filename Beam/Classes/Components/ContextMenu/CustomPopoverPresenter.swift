//
//  CustomPopoverPresenter.swift
//  Beam
//
//  Created by Remi Santos on 23/03/2021.
//

import Foundation

final class CustomPopoverPresenter {
    static let shared = CustomPopoverPresenter()

    static func padding(for view: FormatterView? = nil) -> CGSize {
        let extraPadding = view?.extraPadding ?? .zero
        return .init(width: windowViewPadding + extraPadding.width, height: windowViewPadding + extraPadding.height)
    }

    private static let windowViewPadding: CGFloat = 50

    private var presentedFormatterViews: [FormatterView] = []
    private var presentedUnknownWindows: [PopoverWindow] = []

    private init() {
    }

    /// Will dismiss all presented popovers for a given key, or all of them.
    ///
    /// - Parameters:
    ///     - key: if no key is provided, all visible popovers will be dismissed.
    ///     - animated: will animate out the presented FormatterViews
    func dismissPopovers(key: String? = nil, animated: Bool = true) {
        var views = presentedFormatterViews
        if let key = key {
            views = views.filter { $0.key == key }
            presentedFormatterViews.removeAll { $0.key == key }
        } else {
            presentedFormatterViews.removeAll()
            presentedUnknownWindows.forEach { dismissWindow($0) }
            presentedUnknownWindows.removeAll()
        }
        views.forEach { v in
            if animated {
                v.animateOnDisappear(completionHandler: { [weak self] in
                    self?.dismissWindow(v.window)
                })
            } else {
                dismissWindow(v.window)
            }
        }
    }

    func dismissPopoverWindow(_ window: PopoverWindow) {
        presentedUnknownWindows.removeAll(where: { $0 === window })
        dismissWindow(window)
    }

    private func dismissWindow(_ w: NSWindow?) {
        guard let w = w, w.isVisible else { return }
        w.close()
        w.parent?.removeChildWindow(w)
    }

    @discardableResult
    func presentFormatterView(_ view: FormatterView, atPoint: CGPoint,
                              from fromView: NSView? = nil, animated: Bool = true, in window: NSWindow? = nil) -> NSWindow? {
        let window = presentPopoverChildWindow(canBecomeKey: view.canBecomeKeyView, canBecomeMain: false,
                                               withShadow: false, movable: false, storedInPresenter: false, in: window)
        let position = fromView?.convert(atPoint, to: nil) ?? atPoint
        let idealSize = view.idealSize
        let viewPadding = Self.padding(for: view) // give some space for shadow + possible extra content outside
        var rect = CGRect(origin: position, size: idealSize).insetBy(dx: -viewPadding.width, dy: -viewPadding.height)
        rect.origin.y -= idealSize.height
        let container = NSView(frame: CGRect(origin: .zero, size: rect.size))
        container.autoresizingMask = [.width, .height]
        container.addSubview(view)
        view.frame = CGRect(origin: CGPoint(x: viewPadding.width, y: viewPadding.height), size: idealSize)
        window?.setView(with: container, at: rect.origin)
        window?.setContentSize(rect.size)
        presentedFormatterViews.append(view)

        if animated {
            DispatchQueue.main.async { view.animateOnAppear() }
        }
        if view.canBecomeKeyView {
            window?.makeKeyAndOrderFront(nil)
        }
        return window
    }

    func presentPopoverChildWindow(canBecomeKey: Bool = true, canBecomeMain: Bool = true,
                                   withShadow: Bool = true, useBeamShadow: Bool = false, lightBeamShadow: Bool = false, movable: Bool = true,
                                   autocloseIfNotMoved: Bool = true, storedInPresenter: Bool = false, in parentMenuWindow: NSWindow? = nil) -> PopoverWindow? {

        let window = PopoverWindow(canBecomeMain: canBecomeMain, canBecomeKey: canBecomeKey, useBeamShadow: useBeamShadow, lightBeamShadow: lightBeamShadow, autocloseIfNotMoved: autocloseIfNotMoved)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = withShadow
        window.isMovable = movable

        if let parentMenuWindow = parentMenuWindow {
            parentMenuWindow.highestParent().addChildWindow(window, ordered: .above)
        } else {
            guard let mainWindow = AppDelegate.main.window else { return nil }
            mainWindow.addChildWindow(window, ordered: .above)
        }

        if storedInPresenter {
            presentedUnknownWindows.append(window)
        }
        return window
    }
}
