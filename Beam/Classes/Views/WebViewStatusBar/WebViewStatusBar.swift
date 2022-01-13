import SwiftUI

private struct WebViewStatusBar<Content: View>: View {

    private let isVisible: Bool
    private let content: Content

    init(isVisible: Bool, content: Content) {
        self.isVisible = isVisible
        self.content = content
    }

    var body: some View {
        ZStack {
            if isVisible {
                content
                    .padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
                    .background(background)
                    .transition(.webViewStatusBarTransition(delay: 0.3))
            }
        }
        .padding(10)
    }

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(BeamColor.WebViewStatusBar.border.swiftUI, lineWidth: 1)

            VisualEffectView(material: .hudWindow)
                .overlay(BeamColor.WebViewStatusBar.background.swiftUI)
                .cornerRadius(4)
        }
        .animation(nil)
        .accessibilityIdentifier("webview-status-bar")
    }

}

private struct WebViewStatusBarModifier<StatusBarContent>: ViewModifier where StatusBarContent: View {

    private let isVisible: Bool
    private let statusBarContent: StatusBarContent

    init(isVisible: Bool, content: StatusBarContent) {
        self.isVisible = isVisible
        statusBarContent = content
    }

    func body(content: Content) -> some View {
        content.overlay(
            WebViewStatusBar(isVisible: isVisible, content: statusBarContent),
            alignment: .bottomLeading
        )
    }

}

extension AnyTransition {

    fileprivate static func webViewStatusBarTransition(delay: CGFloat) -> AnyTransition {
        .asymmetric(
            insertion: webViewStatusBarInsertionTransition,
            removal: webViewStatusBarRemovalTransition(delay: delay)
        )
    }

    private static var webViewStatusBarInsertionTransition: AnyTransition {
        .modifier(
            active: WebViewStatusBarTransitionModifier(opacity: 0),
            identity: WebViewStatusBarTransitionModifier(opacity: 1)
        )
    }

    private static func webViewStatusBarRemovalTransition(delay: CGFloat) -> AnyTransition {
        .modifier(
            active: WebViewStatusBarTransitionModifier(opacity: 0, delay: delay),
            identity: WebViewStatusBarTransitionModifier(opacity: 1)
        )
    }

}

private struct WebViewStatusBarTransitionModifier: ViewModifier {

    let opacity: CGFloat
    let delay: CGFloat

    private let duration: CGFloat = 0.2

    private var animation: Animation {
        BeamAnimation.easeOut(duration: duration).delay(delay)
    }

    init(opacity: CGFloat, delay: CGFloat = 0) {
        self.opacity = opacity
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .animation(animation, value: opacity)
    }

}

extension WebView {

    func webViewStatusBar<Content: View>(isVisible: Bool = true, @ViewBuilder content: () -> Content) -> some View {
        modifier(WebViewStatusBarModifier(isVisible: isVisible, content: content()))
    }

}
