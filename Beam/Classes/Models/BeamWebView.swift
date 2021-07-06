import Foundation
import WebKit

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

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        allowsBackForwardNavigationGestures = true
        allowsLinkPreview = true
        allowsMagnification = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
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

    var preventScrolling: Bool = false
    public override func scrollWheel(with theEvent: NSEvent) {
        guard preventScrolling else {
            super.scrollWheel(with: theEvent)
            return
        }
        nextResponder?.scrollWheel(with: theEvent)
    }
}
