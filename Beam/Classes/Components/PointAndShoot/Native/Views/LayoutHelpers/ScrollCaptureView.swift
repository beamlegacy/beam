//
//  ScrollCaptureView.swift
//  Beam
//
//  Created by Stef Kors on 28/09/2021.
//

import SwiftUI

/// An NSView converted to a Swift UIView that captues the scrollWheel event
struct ScrollCaptureView<Content>: NSViewRepresentable where Content: View {
    class ScrollCaptureNSView: NSView {
        var onScroll: ((NSEvent) -> Void)?

        override func scrollWheel(with theEvent: NSEvent) {
            super.scrollWheel(with: theEvent)
            onScroll?(theEvent)
        }
    }

    var onScroll: ((NSEvent) -> Void)?
    var content: Content

    func makeNSView(context: Context) -> ScrollCaptureNSView {
        let parent = ScrollCaptureNSView()
        let child = NSHostingController(rootView: content)
        parent.addSubviewWithConstraintsOnEachSide(subView: child.view)
        parent.autoresizingMask = [.width, .height]
        // First, add the view of the child to the view of the parent
        child.view.translatesAutoresizingMaskIntoConstraints = false

        parent.onScroll = onScroll
        return parent
    }

    func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {}
}

struct ScrollCaptureSwiftUIViewModifier: ViewModifier {
    var onScroll: ((NSEvent) -> Void)?

    func body(content: Content) -> some View {
            ScrollCaptureView(onScroll: { event in
                onScroll?(event)
            }, content: content)
    }
}

extension View {
    /// Forward the scrollWheel NSEvent to Swift UI by stacking a NSView on top of the view content.
    /// - Parameter onScroll: Scroll callback with NSEvent
    func onScroll(_ onScroll: ((NSEvent) -> Void)?) -> some View {
        return modifier(ScrollCaptureSwiftUIViewModifier(onScroll: onScroll))
    }
}
