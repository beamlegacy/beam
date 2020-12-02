//
//  BrowserTab.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import Combine
import WebKit
import FavIcon

class FullScreenWKWebView: WKWebView {
//    override var safeAreaInsets: NSEdgeInsets {
//        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }
}

class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var id: UUID

    public func load(url: URL) {
        self.url = url
        webView.load(URLRequest(url: url))
    }

    @Published public var webView: WKWebView! {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String = ""
    @Published var originalQuery: String = ""
    @Published var url: URL?
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false
    @Published var serverTrust: SecTrust?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList!
    @Published var visitedURLs = Set<URL>()
    @Published var favIcon: NSImage?

    @Published var privateMode = false

    var state: BeamState!

    var note: BeamNote?
    var element: BeamElement?

    var appendToIndexer: (URL, Readability) -> Void = { _, _ in }

    var creationDate: Date = Date()
    var lastViewDate: Date = Date()
    var accumulatedViewDuration: TimeInterval = 0

    public var onNewTabCreated: (BrowserTab) -> Void = { _ in }

    private var scope = Set<AnyCancellable>()

    override init() {
        self.id = UUID()
        super.init()
    }

    class var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.tabFocusesLinks = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        return config
    }

    init(state: BeamState, originalQuery: String, note: BeamNote?, id: UUID = UUID(), webView: WKWebView? = nil ) {
        self.state = state
        self.id = id
        self.note = note
        self.originalQuery = originalQuery

        if !originalQuery.isEmpty, let note = self.note {
            let e = BeamElement()
            element = e
            note.addChild(e)
        }

        if let w = webView {
            self.webView = w
            backForwardList = w.backForwardList
        } else {
            let web = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
            web.wantsLayer = true

            state.setup(webView: web)
            backForwardList = web.backForwardList
            self.webView = web
        }

        super.init()
        setupObservers()
    }

    private func updateBullet() {
        if let url = url {
            let name = title.isEmpty ? url.absoluteString : title
            self.element?.text = "[\(name)](\(url.absoluteString))"
        }
    }

    private func updateFavIcon() {
        guard let url = url else { favIcon = nil; return }
        do {
            try FavIcon.downloadPreferred(url, width: 16, height: 16) { [weak self] result in
                guard let self = self else { return }

                if case let .success(image) = result {
                  // On iOS, this is a UIImage, do something with it here.
                  // This closure will be executed on the main queue, so it's safe to touch
                  // the UI here.
                    self.favIcon = image
                } else {
                    self.favIcon = nil
                }
            }
        } catch {
            self.favIcon = nil
        }
    }

    private func setupObservers() {
        webView.publisher(for: \.title).sink { v in
            self.title = v ?? "loading..."
            self.updateBullet()
        }.store(in: &scope)
        webView.publisher(for: \.url).sink { v in
            self.url = v
            self.updateBullet()
            self.updateFavIcon()
        }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink { v in withAnimation { self.isLoading = v } }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink { v in withAnimation { self.estimatedProgress = v } }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent).sink { v in self.hasOnlySecureContent = v }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink { v in self.serverTrust = v }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink { v in self.canGoBack = v }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink { v in self.canGoForward = v }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink { v in self.backForwardList = v }.store(in: &scope)

        webView.navigationDelegate = self
        webView.uiDelegate = self

        self.webView.configuration.userContentController.removeAllUserScripts()

        self.webView.configuration.userContentController.removeScriptMessageHandler(forName: TextSelectedMessage)
        self.webView.configuration.userContentController.removeScriptMessageHandler(forName: OnScrolledMessage)
        self.webView.configuration.userContentController.removeScriptMessageHandler(forName: JSLogger)

        self.webView.configuration.userContentController.add(self, name: JSLogger)
        self.webView.configuration.userContentController.add(self, name: TextSelectedMessage)
        self.webView.configuration.userContentController.add(self, name: OnScrolledMessage)

        self.webView.configuration.userContentController.addUserScript(WKUserScript(source: overrideConsole, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        self.webView.configuration.userContentController.addUserScript(WKUserScript(source: jsSelectionObserver, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

    }

    func cancelObservers() {
        scope.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        self.webView.configuration.userContentController.removeScriptMessageHandler(forName: TextSelectedMessage)
        self.webView.configuration.userContentController.removeScriptMessageHandler(forName: OnScrolledMessage)
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        var isSearchResult = false
        if let targetURL = navigationAction.request.url {
            if let currentHost = self.webView.url?.host {
                if let targetHost = targetURL.host {
                    let startsWithURL = targetURL.path.hasPrefix("/url")
                    isSearchResult = currentHost.hasSuffix("google.com") && targetHost.hasSuffix("google.com") && startsWithURL && !visitedURLs.isEmpty
                }
            }

            if navigationAction.modifierFlags.contains(.command) != isSearchResult {
                // Create new tab
                let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
                newWebView.wantsLayer = true
                state.setup(webView: newWebView)
                let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: note, webView: newWebView)
                newTab.load(url: targetURL)
                onNewTabCreated(newTab)
                decisionHandler(.cancel, preferences)
                return
            }

            visitedURLs.insert(targetURL)
        }
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    lazy var overrideConsole: String = { loadJS(from: "OverrideConsole") }()

    let enableJavascriptLogs = true

    let TextSelectedMessage = "beam_textSelected"
    let OnScrolledMessage = "beam_onScrolled"
    let JSLogger = "logging"

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case JSLogger:
            if enableJavascriptLogs {
                print(message.body)
            }

        case TextSelectedMessage:
            guard let dict = message.body as? [String: AnyObject],
//                  let selectedText = dict["selectedText"] as? String,
                  let selectedHtml = dict["selectedHtml"] as? String,
                  !selectedHtml.isEmpty
            else { return }
//            print("Text selected: \(selectedText)")
//            print("Html selected: \(selectedHtml)")

            let text = html2Md(url: webView.url!, html: selectedHtml)

//            print("html to MD (\(url)): \(text)")

            // now add a bullet point with the quoted text:
            if let urlString = webView.url?.absoluteString, let title = webView.title {
                guard let url = urlString.markdownizedURL else { return }
                let quote = "> \(text) - from [\(title)](\(url))"

                DispatchQueue.main.async {
                    let e = BeamElement()
                    e.text = quote
                    _ = self.note?.addChild(e)
                }
            }
        case OnScrolledMessage:
            guard let dict = message.body as? [String: AnyObject],
//                  let selectedText = dict["selectedText"] as? String,
                let x = dict["x"] as? Double,
                let y = dict["y"] as? Double
            else { return }
            Logger.shared.logDebug("Web Scrolled: \(x), \(y)", category: .web)
        default:
            break
        }
    }

    lazy var jsSelectionObserver: String = { loadJS(from: "SelectionObserver") }()

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            Readability.read(webView) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case let .success(read):
                    self.appendToIndexer(url, read)
                case let .failure(error):
                    print("Error while indexing web page: \(error)")
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }

    // WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: configuration)
        newWebView.wantsLayer = true
        state.setup(webView: newWebView)
        let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: self.note, webView: newWebView)
        onNewTabCreated(newTab)

        return newTab.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Logger.shared.logDebug("webView runJavaScriptAlertPanelWithMessage \(message)", category: .web)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptConfirmPanelWithMessage \(message)", category: .web)
        completionHandler(true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptTextInputPanelWithPrompt \(prompt) default: \(defaultText ?? "")", category: .web)
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        Logger.shared.logDebug("webView runOpenPanel", category: .web)
        completionHandler(nil)
    }

    func startViewing() {
        lastViewDate = Date()
    }

    func stopViewing() {
        accumulatedViewDuration += lastViewDate.distance(to: Date())
    }
}
