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

    weak var page: WebPage?
    private let automaticallyResignResponder = true

    var monitor: Any?
    fileprivate var currentConfiguration: WKWebViewConfiguration

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        currentConfiguration = configuration
        super.init(frame: frame, configuration: configuration)
        allowsBackForwardNavigationGestures = true
        allowsLinkPreview = true
        allowsMagnification = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [unowned self] event in
            optionKeyToggle(event.modifierFlags)
            return event
        }
    }

    deinit {
        guard let monitor = monitor else { return }
        NSEvent.removeMonitor(monitor)
    }

    required init?(coder: NSCoder) {
        fatalError()
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
        super.keyDown(with: event)
    }

    public override func flagsChanged(with event: NSEvent) {
        super.keyUp(with: event)
        optionKeyToggle(event.modifierFlags)
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
        // clickc event
    }

    var mouseMoveTriggeredChange: (NSPoint, NSEvent.ModifierFlags) -> Void = { (_, _) in
        // update the positions of the point and shoot elements
    }
    var preventScrolling: Bool = false

    public override func mouseDown(with theEvent: NSEvent) {
        super.mouseDown(with: theEvent)
        mouseClickChange(convert(theEvent.locationInWindow, from: nil))
    }

    public override func scrollWheel(with theEvent: NSEvent) {
        guard preventScrolling else {
            super.scrollWheel(with: theEvent)
            mouseMoveTriggeredChange(convert(theEvent.locationInWindow, from: nil), theEvent.modifierFlags)
            return
        }
        nextResponder?.scrollWheel(with: theEvent)
        mouseMoveTriggeredChange(convert(theEvent.locationInWindow, from: nil), theEvent.modifierFlags)
    }

    public override func mouseMoved(with theEvent: NSEvent) {
        super.mouseMoved(with: theEvent)
        mouseMoveTriggeredChange(convert(theEvent.locationInWindow, from: nil), theEvent.modifierFlags)
    }

    public override func mouseDragged(with theEvent: NSEvent) {
        super.mouseDragged(with: theEvent)
        mouseMoveTriggeredChange(convert(theEvent.locationInWindow, from: nil), theEvent.modifierFlags)
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
