//
//  RetroCompatibleScrollViewReader.swift
//  Beam
//
//  Created by Remi Santos on 12/05/2021.
//

import SwiftUI

private let RetroCompatibleScrollViewContentID = "RetroCompatibleContentID"
private let forceCustomProxyForDebug = false

// Equivalent to ScrollViewReader that will forward a SwiftUI 2 ScrollViewProxy or an equivalent for older version.
// Until we drop Catalina support (https://developer.apple.com/documentation/swiftui/scrollviewproxy)
struct RetroCompatibleScrollViewReader<Content: View>: View {

    let content: (RetroCompatibleScrollViewProxy) -> Content

    @State private var scrollViewProxy: RetroCompatibleScrollViewProxy = RetroCompatibleScrollViewProxy()
    @State private var customScrollingProxy: CustomScrollingProxy?

    var body: some View {
        if #available(macOS 11.0, *), !forceCustomProxyForDebug {
            ScrollViewReader { nativeProxy in
                content(RetroCompatibleScrollViewProxy(withScrollViewProxy: nativeProxy))
                    .id(RetroCompatibleScrollViewContentID)
            }
        } else {
            content(scrollViewProxy)
                .background(CustomScrollingHelper(proxy: customScrollingProxy))
                .onAppear {
                    DispatchQueue.main.async {
                        let newProxy = CustomScrollingProxy()
                        customScrollingProxy = newProxy
                        scrollViewProxy = RetroCompatibleScrollViewProxy(withCustomScrollViewProxy: newProxy)
                        let droppedPoint = RetroCompatibleScrollViewProxy.droppedScrollToPoint
                        if droppedPoint != .zero {
                            DispatchQueue.main.async {
                                scrollViewProxy.scrollTo(droppedPoint)
                            }
                        }
                    }
                }
        }
    }
}

struct RetroCompatibleScrollViewProxy: Equatable {

    static func == (lhs: RetroCompatibleScrollViewProxy, rhs: RetroCompatibleScrollViewProxy) -> Bool {
        return lhs.id == rhs.id
    }
    fileprivate var id = UUID().uuidString

    // Either native SwiftUI 2 (macOS 11) ScrollViewProxy or our implementation for < 11.0
    private var scrollViewProxy: Any?

    @available(macOS 11.0, *)
    fileprivate init(withScrollViewProxy proxy: ScrollViewProxy) {
        self.scrollViewProxy = proxy
    }

    @available(macOS, introduced: 10.15, deprecated: 11.0, message: "Use native SwiftUI ScrollViewReader/Proxy instead")
    fileprivate init(withCustomScrollViewProxy proxy: CustomScrollingProxy) {
        self.scrollViewProxy = proxy
    }
    // if we try to scroll before the scroll view is ready, we store it temporarily
    fileprivate static var droppedScrollToPoint: CGPoint = .zero

    fileprivate init() { self.id = "emptyProxy" }

    func scrollTo(_ point: CGPoint) {
        Self.droppedScrollToPoint = .zero
        if #available(macOS 11.0, *), !forceCustomProxyForDebug {
            guard let proxy = scrollViewProxy as? ScrollViewProxy else { return }
            proxy.scrollTo(RetroCompatibleScrollViewContentID, anchor: UnitPoint.init(x: point.x, y: point.y))
        } else {
            guard let proxy = scrollViewProxy as? CustomScrollingProxy else {
                Self.droppedScrollToPoint = point
                return
            }
            proxy.scrollTo(.point(point))
        }
    }
}

// For macOS < 11, we wrap the view and try to keep a reference to the parent scrollView
// by going through the view hierarchy.
private struct CustomScrollingHelper: NSViewRepresentable {

    var proxy: CustomScrollingProxy?

    func makeNSView(context: Context) -> NSView {
        let view = NSView() // managed by SwiftUI, no overloads
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        proxy?.catchScrollView(for: nsView) // here NSView is in view hierarchy
    }
}

private class CustomScrollingProxy {

    enum Action {
        case trailing
        case top
        case bottom
        case point(_ point: CGPoint)
        case rect(_ rect: CGRect)
    }

    var lastScrollPoint: CGPoint = .zero

    private var clipView: NSClipView?

    func catchScrollView(for view: NSView) {
        guard clipView == nil else { return }
        clipView = view.enclosingClipView()
    }

    func scrollTo(_ action: Action) {
        guard let clipView = clipView else { return }
        var rect = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        switch action {
        case .trailing:
            rect.origin.x = clipView.frame.minX
            if let documentWidth = clipView.documentView?.frame.width {
                rect.origin.x = documentWidth - clipView.bounds.size.width
            }
        case .bottom:
            rect.origin.y = clipView.frame.minY
            if let documentHeight = clipView.documentView?.frame.height {
                rect.origin.y = documentHeight - clipView.bounds.size.height
            }
        case .point(let point):
            lastScrollPoint = point
            rect.origin = point
        case .rect(let r):
            rect = r
        default:
            break
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            clipView.scrollToVisible(rect)
        }
    }
}

private extension NSView {
    func enclosingClipView() -> NSClipView? {
        var next: NSView? = self
        repeat {
            next = next?.superview
            if let cv = next as? NSClipView {
                return cv
            }
        } while next != nil
        return nil
    }
}
