import AppKit
import SwiftUI

/// A ``NSMenuItem`` subclass taking a SwiftUI view as its content.
final class ContentViewMenuItem<ContentView: View>: NSMenuItem {
    typealias ContentBuilder = () -> ContentView
    typealias CustomizationHandler = (NSHostingView<ContentView>) -> Void

    private final class ContainerView: NSView {
        override var acceptsFirstResponder: Bool {
            return storage
        }

        private let storage: Bool

        init(acceptsFirstResponder: Bool) {
            self.storage = acceptsFirstResponder
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    /// Constructs an item with a specified SwiftUI content view.
    /// - Parameters:
    ///   - title: The title of the menu item.
    ///   - keyEquivalent: A string representing a keyboard key to be used as the key equivalent.
    ///   - acceptsFirstResponder: A Boolean value that indicates whether the responder accepts first responder status, defaults to `true.
    ///   - contentView: A ``SwiftUI/ViewBuilder`` that produces the view.
    ///   - insets: A ``NSEdgeInsets`` for the content, defaults to `.zero`.
    ///   - customization: A closure allowing to further customize the view hosting the SwiftUI view.
    ///
    ///   You can use the ``customization`` closure to further constraints the container view, since
    ///   SwiftUI might not communicate its intrinsic size.
    init(
        title: String,
        keyEquivalent: String = "",
        acceptsFirstResponder: Bool = true,
        @ViewBuilder contentView: @escaping ContentBuilder,
        insets: NSEdgeInsets = .init(top: .zero, left: .zero, bottom: .zero, right: .zero),
        customization: CustomizationHandler? = nil
    ) {
        super.init(title: title, action: nil, keyEquivalent: keyEquivalent)

        let hostingView = NSHostingView<ContentView>(rootView: contentView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = ContainerView(acceptsFirstResponder: acceptsFirstResponder)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets.left),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -insets.right),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets.bottom)
        ])

        self.view = container

        customization?(hostingView)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
