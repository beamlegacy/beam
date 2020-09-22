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

class BrowserTab: ObservableObject, Identifiable {
    var id: UUID
    
    public func load(url: URL) {
        webView.load(URLRequest(url: url))
    }
    
    @Published public var webView: WKWebView {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String = ""
    @Published var url: URL? = nil
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false
    @Published var serverTrust: SecTrust? = nil
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList

    private var scope = Set<AnyCancellable>()

    init(id: UUID = UUID(), title: String = "") {
        self.id = id
        self.title = title
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.tabFocusesLinks = true
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        let web = WKWebView(frame: NSRect(), configuration: configuration)
        self.webView = web
        backForwardList = web.backForwardList
        setupObservers()


    }
    
    
    private func setupObservers() {
        webView.publisher(for: \.title).sink() { v in self.title = v ?? "loading..." }.store(in: &scope)
        webView.publisher(for: \.url).sink() { v in self.url = v }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink() { v in self.isLoading = v }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink() { v in self.estimatedProgress = v }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent).sink() { v in self.hasOnlySecureContent = v }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink() { v in self.serverTrust = v }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink() { v in self.canGoBack = v }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink() { v in self.canGoForward = v }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink() { v in self.backForwardList = v }.store(in: &scope)
    }



}

