import SwiftUI

struct CursorOverrideModifier: ViewModifier {

    private let cursor: NSCursor

    init(cursor: NSCursor) {
        self.cursor = cursor
    }

    func body(content: Content) -> some View {
        content.background(
            CursorOverrideView(cursor: cursor)
        )
    }

}

private struct CursorOverrideView: NSViewRepresentable {

    private let cursor: NSCursor

    init(cursor: NSCursor) {
        self.cursor = cursor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(cursor: cursor)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        let options: NSTrackingArea.Options = [
            .activeAlways,
            .inVisibleRect,
            .mouseMoved
        ]

        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: options,
            owner: context.coordinator,
            userInfo: nil
        )

        view.addTrackingArea(trackingArea)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class Coordinator: NSResponder {

        private let cursor: NSCursor

        init(cursor: NSCursor) {
            self.cursor = cursor
            super.init()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func mouseMoved(with event: NSEvent) {
            cursor.set()
        }

    }

}

extension View {

    /// Force-updates the cursor every time it moves above this view, to cancel any cursor updates from tracking areas
    /// underneath.
    func cursorOverride(_ cursor: NSCursor) -> some View {
        modifier(CursorOverrideModifier(cursor: cursor))

    }
}
