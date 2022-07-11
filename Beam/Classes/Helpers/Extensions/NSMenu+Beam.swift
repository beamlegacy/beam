import AppKit
import SwiftUI

// MARK: - NSMenuItem subclasses

/// A ``NSMenuItem`` subclass containing a closure for easy menus creation.
final class HandlerMenuItem: NSMenuItem {
    typealias Handler = (NSMenuItem) -> Void

    let handler: Handler

    init(title: String, keyEquivalent: String = "", handler: @escaping Handler) {
        self.handler = handler
        super.init(title: title, action: #selector(performAction(_:)), keyEquivalent: keyEquivalent)
        self.target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performAction(_ item: NSMenuItem) {
        handler(item)
    }
}

// MARK: - NSMenuItem components

extension NSMenuItem {
    /// A separator that will take the full width of the menu.
    /// - Parameter height: the height of the separator, defaults to `1.0` point.
    /// - Returns: A menu item that is used to separate logical groups of menu commands.
    class func fullWidthSeparator(height: CGFloat = 1.0) -> NSMenuItem {
        return ContentViewMenuItem(
            title: "BeamFullWidthSeparator",
            contentView: { Divider().background(BeamColor.Generic.macOSContextSeparator.swiftUI) },
            insets: NSEdgeInsets(top: .zero, left: .zero, bottom: 5.0, right: .zero),
            customization: { hostingView in
                hostingView.heightAnchor.constraint(equalToConstant: height).isActive = true
            }
        )
    }
}

// MARK: - NSMenu helpers

extension NSMenu {
    /// Adds a menu item to the end of the menu with a specified handler.
    /// - Parameters:
    ///   - title: A string to be made the title of the menu item.
    ///   - keyEquivalent: A string identifying the key to use as a key equivalent for the menu item.
    ///   - handler: The closure that will be executed when this item is selected.
    /// - Returns: The created menu item.
    @discardableResult
    func addItem(withTitle title: String, keyEquivalent: String = "", handler: @escaping HandlerMenuItem.Handler) -> NSMenuItem {
        let item = HandlerMenuItem(title: title, keyEquivalent: keyEquivalent, handler: handler)
        addItem(item)
        return item
    }
}
