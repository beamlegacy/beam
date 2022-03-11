import Foundation
import WebKit
import BeamCore

@objc
private class BeamWebViewAutoClose: NSObject, WKUIDelegate {
    init(delegate: WKUIDelegate?) {
        self.delegate = delegate
    }

    weak var delegate: WKUIDelegate?

    func webViewDidClose(_ webView: WKWebView) {
        delegate?.webViewDidClose?(webView)
        webView.window?.close()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        delegate?.webView?(webView, createWebViewWith: configuration, for: navigationAction, windowFeatures: windowFeatures)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        delegate?.webView?(webView, runJavaScriptAlertPanelWithMessage: message, initiatedByFrame: frame, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        delegate?.webView?(webView, runJavaScriptConfirmPanelWithMessage: message, initiatedByFrame: frame, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        delegate?.webView?(webView, runJavaScriptTextInputPanelWithPrompt: prompt, defaultText: defaultText, initiatedByFrame: frame, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        delegate?.webView?(webView, runOpenPanelWith: parameters, initiatedByFrame: frame, completionHandler: completionHandler)
    }
}

class BeamWebView: WKWebView {

#if TEST || DEBUG
    static var aliveWebViewsCount: Int = 0
#endif

    weak var page: WebPage?
    private let automaticallyResignResponder = true

    var monitor: Any?
    fileprivate var currentConfiguration: WKWebViewConfiguration

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        Self.setURLSchemeHandlers(in: configuration)
        currentConfiguration = configuration
        super.init(frame: frame, configuration: configuration)
        allowsBackForwardNavigationGestures = true
        allowsLinkPreview = true
        allowsMagnification = true
        customUserAgent = Constants.SafariUserAgent

        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self, self.page != nil else { return event }
            self.optionKeyToggle(event.modifierFlags)
            return event
        }
        #if TEST || DEBUG
            Self.aliveWebViewsCount += 1
        #endif

        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        self._setAddsVisitedLinks(true)
        #endif
    }

    deinit {
        #if TEST || DEBUG
            Self.aliveWebViewsCount -= 1
        #endif
        guard let monitor = monitor else { return }
        NSEvent.removeMonitor(monitor)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func cursorUpdate(with event: NSEvent) {
        // This override fixes the cursor blinking when WebView is overlayed by a Swift UI View
        // BE-2205: https://linear.app/beamapp/issue/BE-2205/cursor-blinks-in-web-mode
    }

    override func viewDidMoveToSuperview() {
        if automaticallyResignResponder && superview == nil && self.window?.firstResponder == self {
            self.window?.makeFirstResponder(nil)
        }
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = BeamColor.Generic.background.cgColor
    }

    // Catching those event to avoid funk sound
    override func keyDown(with event: NSEvent) {
        if let key = event.specialKey {
            if key == .leftArrow || key == .rightArrow {
                return
            }
        }

        if event.keyCode == KeyCode.escape.rawValue && page?.searchViewModel != nil {
            page?.cancelSearch()
            return
        }

        if let keyCode = KeyCode(rawValue: event.keyCode), keyCode == .s, event.modifierFlags.contains(.option) {
            page?.collectTab()
            return
        }

        super.keyDown(with: event)
    }

    public override func flagsChanged(with event: NSEvent) {
        super.keyUp(with: event)
        if let window = event.window, window.isKeyWindow {
            optionKeyToggle(event.modifierFlags)
        }
    }

    //swiftlint:disable:next weak_delegate
    private var autoCloseDelegate: BeamWebViewAutoClose?
    var enableAutoCloseWindow: Bool {
        get {
            autoCloseDelegate != nil
        }

        set {
            guard newValue != enableAutoCloseWindow else { return }
            if newValue {
                let del = BeamWebViewAutoClose(delegate: self.uiDelegate)
                self.autoCloseDelegate = del
                self.uiDelegate = del
            } else if let del = autoCloseDelegate {
                uiDelegate = del.delegate
                self.autoCloseDelegate = nil
            }
        }
    }

    public func setupForEmbed() {
        preventScrolling = true
    }

    var optionKeyToggle: (NSEvent.ModifierFlags) -> Void = { _ in
        // update the positions of the point and shoot elements
    }

    var mouseClickChange: (NSPoint) -> Void = { _ in
        // click event
    }

    var mouseMoveTriggeredChange: (NSPoint, NSEvent.ModifierFlags) -> Void = { (_, _) in
        // update the positions of the point and shoot elements
    }
    var preventScrolling: Bool = false

    private func mouseLocation(from event: NSEvent) -> CGPoint {
        var point = convert(event.locationInWindow, from: nil)
        point.y -= self.topContentInset
        return point
    }

    public override func mouseDown(with theEvent: NSEvent) {
        super.mouseDown(with: theEvent)
        mouseClickChange(mouseLocation(from: theEvent))
    }

    public override func scrollWheel(with theEvent: NSEvent) {
        guard preventScrolling else {
            super.scrollWheel(with: theEvent)
            mouseMoveTriggeredChange(mouseLocation(from: theEvent), theEvent.modifierFlags)
            return
        }
        nextResponder?.scrollWheel(with: theEvent)
        mouseMoveTriggeredChange(mouseLocation(from: theEvent), theEvent.modifierFlags)
    }

    public override func mouseMoved(with theEvent: NSEvent) {
        guard page?.allowsMouseMoved(with: theEvent) != false else { return }
        super.mouseMoved(with: theEvent)
        mouseMoveTriggeredChange(mouseLocation(from: theEvent), theEvent.modifierFlags)
    }

    public override func mouseDragged(with theEvent: NSEvent) {
        super.mouseDragged(with: theEvent)
        mouseMoveTriggeredChange(mouseLocation(from: theEvent), theEvent.modifierFlags)
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        let menuItemIdentifiersToDisable: [NSUserInterfaceItemIdentifier] = [
            .webKitCopyImage,
            .webKitDownloadImage
        ]

        let filteredItems = menu.items.filter { menuItem in
            guard let identifier = menuItem.identifier else { return true }
            return !menuItemIdentifiersToDisable.contains(identifier)
        }

        menu.items = filteredItems
    }

    private static func setURLSchemeHandlers(in configuration: WKWebViewConfiguration) {
        BeamSchemeHandler.responders = [
            LocalPageSchemeHandler.path: LocalPageSchemeHandler()
        ]
        configuration.setURLSchemeHandlerIfNeeded(BeamSchemeHandler(), forURLScheme: BeamURL.scheme)
        NavigationRouter.setCustomURLSchemeHandlers(in: configuration)
    }

}

extension WKWebView {
    /// Works only for a BeamWebView.
    ///
    /// WKWebView's `configuration` is marked with @NSCopying.
    /// So everytime you try to access it, it creates a copy of it, which is most likely not what we want.
    var configurationWithoutMakingCopy: WKWebViewConfiguration {
        (self as? BeamWebView)?.currentConfiguration ?? configuration
    }
}
