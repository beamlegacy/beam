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
import SwiftSoup
import FavIcon

class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var id: UUID

    public func load(url: URL) {
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

    var note: Note?
    var bullet: Bullet?

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

    init(state: BeamState, originalQuery: String, note: Note?, id: UUID = UUID(), webView: WKWebView? = nil ) {
        self.state = state
        self.id = id
        self.note = note
        self.originalQuery = originalQuery

        if !originalQuery.isEmpty, note != nil {
            bullet = self.note?.createBullet(CoreDataManager.shared.mainContext, content: "visiting...")
        }

        if let w = webView {
            self.webView = w
            backForwardList = w.backForwardList
        } else {
            let web = WKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
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
            self.bullet?.content = "visit [\(name)](\(url.absoluteString))"
        }
    }

    private func updateFavIcon() {
        guard let url = url else { favIcon = nil; return }
        do {
            try FavIcon.downloadPreferred(url) { [weak self] result in
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

        self.webView.configuration.userContentController.add(self, name: TextSelectedMessage)
    }

    func injectJSInPage() {
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
                let newWebView = WKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
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

    #if false
    class textNodeVisitor: SwiftSoup.NodeVisitor {
        init() {
        }
        public func head(_ node: Node, _ depth: Int) {
            if let textNode = (node as? TextNode) {
                let string = textNode.getWholeText()
                //                print("Node[\(depth)]: \(string)\n")
            } else if let element = (node as? Element) {
                //                if !accum.isEmpty &&
                //                    (element.isBlock() || element.nodeName() == "br") &&
                //                    !TextNode.lastCharIsWhitespace(accum) {
                ////                    accum.append(" ")
                //                }
            }
        }

        public func tail(_ node: Node, _ depth: Int) {
        }
    }

    class NodeTraversor {
        private let visitor: NodeVisitor

        /**
         * Create a new traversor.
         * @param visitor a class implementing the {@link NodeVisitor} interface, to be called when visiting each node.
         */
        public init(_ visitor: NodeVisitor) {
            self.visitor = visitor
        }

        /**
         * Start a depth-first traverse of the root and all of its descendants.
         * @param root the root node point to traverse.
         */
        open func traverse(_ root: Node?)throws {
            var node: Node? = root
            var depth: Int = 0

            while node != nil {
                try visitor.head(node!, depth)
                if node!.childNodeSize() > 0 {
                    node = node!.childNode(0)
                    depth += 1
                } else {
                    while node!.nextSibling() == nil && depth > 0 {
                        try visitor.tail(node!, depth)
                        node = node!.parent()
                        depth -= 1
                    }
                    try visitor.tail(node!, depth)
                    if node === root {
                        break
                    }
                    node = node!.nextSibling()
                }
            }
        }
    }
    #endif

    let TextSelectedMessage = "beam_textSelected"
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case TextSelectedMessage:
            guard let dict = message.body as? [String: AnyObject],
                  let selectedText = dict["selectedText"] as? String
            else { return }
            print("Text selected: \(selectedText)")

            // now add a bullet point with the quoted text:
            if let urlString = webView.url?.absoluteString, let title = webView.title {
                guard let url = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "()").inverted) else { return }
                let quote = "> \(selectedText) - from [\(title)](\(url))"

                DispatchQueue.main.async {
                    _ = self.note?.createBullet(CoreDataManager.shared.mainContext, content: quote, createdAt: Date(), afterBullet: nil, parentBullet: nil)
                }
            }
        default:
            break
        }
    }

    let jsSelectionObserver = """
    function beam_getSelectedText() {
        if (window.getSelection) {
            return window.getSelection().toString();
        } else if (document.selection) {
            return document.selection.createRange().text;
        }
        return '';
    }

    var beam_currentSelectedText = "";
    function beam_textSelected() {
        window.webkit.messageHandlers.beam_textSelected.postMessage({ selectedText: beam_currentSelectedText });
    }

    document.addEventListener('selectionchange', () => {
        var text = beam_getSelectedText();
        beam_currentSelectedText = text;
    });

    document.addEventListener('select', () => {
        var text = beam_getSelectedText();
        beam_currentSelectedText = text;
    });

    document.addEventListener('keyup', function(e) {
        var key = e.keyCode || e.which;
        if (key == 16) {
            beam_textSelected();
        }
    });

    document.addEventListener('mouseup', function() {
        beam_textSelected();
    });
    """

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

        webView.evaluateJavaScript(jsSelectionObserver) { (any, err) in
            return
        }

        #if false
        webView.evaluateJavaScript("document.body.innerHTML") { (string, _) in
            if let html = string as? String {
                do {
                    let doc: Document = try SwiftSoup.parse(html)
                    //                    let text = try doc.text()
                    try NodeTraversor(textNodeVisitor()).traverse(doc)

                    //                    print("==============================\nAll the text in the document:\n\(text)")
                } catch Exception.Error(let type, let message) {
                    print("SwiftSoup Error(\(type)): \(message)")
                } catch {
                    print("error")
                }
            }
        }
        #endif
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
        let newWebView = WKWebView(frame: NSRect(), configuration: configuration)
        state.setup(webView: newWebView)
        let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: self.note, webView: newWebView)
        onNewTabCreated(newTab)

        return newTab.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        print("webView webDidClose")
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("webView runJavaScriptAlertPanelWithMessage \(message)")
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("webView runJavaScriptConfirmPanelWithMessage \(message)")
        completionHandler(true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        print("webView runJavaScriptTextInputPanelWithPrompt \(prompt) default: \(defaultText ?? "")")
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        print("webView runOpenPanel")
        completionHandler(nil)
    }

    func startViewing() {
        lastViewDate = Date()
    }

    func stopViewing() {
        accumulatedViewDuration += lastViewDate.distance(to: Date())
    }
}
