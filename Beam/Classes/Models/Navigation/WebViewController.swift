//
//  WebViewController.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2022.
//

import Foundation
import WebKit
import Combine
import BeamCore

private struct BackForwardURLTriplet {
    let backUrl: URL?
    let currentUrl: URL?
    let forwardUrl: URL?

    init(list: WKBackForwardList) {
        self.backUrl = list.backItem?.url
        self.currentUrl = list.currentItem?.url
        self.forwardUrl = list.forwardItem?.url
    }
}
struct WebViewNavigationDescription {
    let url: URL
    let source: WebViewControllerNavigationSource
    let isLinkActivation: Bool
    /// Last user requested URL, before any implicit redirection happened
    let requestedURL: URL?
    let time: Date = BeamDate.now
    let keepSameParent: Bool
}

protocol WebViewControllerDelegate: AnyObject {

    /// The webView received a new URL that we should display.
    ///
    /// - For navigation on the same domain it will be forwarded as soon as the webView.url value changes.
    /// - For navigation to a different domain, we will wait for `webview:didCommit` delegate.
    ///
    /// See callers for more details.
    func webViewController(_ controller: WebViewController, didChangeDisplayURL url: URL)

    /// Helper to react to webView properties changes
    func webViewController<Value>(_ controller: WebViewController, observedValueChangedFor keyPath: KeyPath<WKWebView, Value>, value: Value)

    /// The webView is going back or forward in history.
    /// A call to didFinishNavigationToURL is expected after.
    func webViewController(_ controller: WebViewController, willMoveInHistory forward: Bool)

    /// The webView has actually started to load content for a page but is not finished yet.
    ///
    /// Equivalent to`webview:didCommit` webKit delegate.
    func webViewControllerIsNavigatingToANewPage(_ controller: WebViewController)

    /// The webView is done loading content for a page.
    ///
    /// Equivalent to`webview:didFinish` webKit delegate.
    func webViewController(_ controller: WebViewController, didFinishNavigatingToPage navigationDescription: WebViewNavigationDescription)

    /// The webView is displaying a new kind of content, a PDF document for exemple.
    func webViewController(_ controller: WebViewController, didChangeLoadedContentType contentDescription: BrowserContentDescription?)
}

/**
 * WebViewController helps understand navigation events and properties changes
 *
 * It is mostly here to gather WKNavigationDelegate and Javascript navigation events.
 *
 * It will provide answers to the navigation needs, and forward only relevant navigation events to its delegate.
 */
class WebViewController {

    private weak var webView: WKWebView? {
        didSet {
            setupWebViewValuesObservers()
        }
    }
    let webkitNavigationHandler = WebKitNavigationHandler()
    weak var delegate: WebViewControllerDelegate?

    // Ideally we shouldn't need full access to page here, simply delegate.
    // But for now we have some error/download/password management that requires it.
    weak var page: WebPage? {
        didSet {
            webkitNavigationHandler.page = page
        }
    }

    /// The URL before any website implicit redirection. (ex: gmail.com redirects to mail.google.com)
    private var requestedURL: URL?
    private let maxTimeSinceLastNavigationForRedirection = 0.5 // seconds
    private var lastNavigationFinished: WebViewNavigationDescription?
    private var lastNavigationWasTriggeredByBeamUI = false

    init(with webView: WKWebView) {
        self.webView = webView
        setupWebViewValuesObservers()
        webView.navigationDelegate = webkitNavigationHandler
    }

    // MARK: - WebView Values Observers
    private var observersCancellables = Set<AnyCancellable>()
    private var contextDependentObserversCancellables = Set<AnyCancellable>()
    private var contentDescription: BrowserContentDescription? {
        didSet {
            delegate?.webViewController(self, didChangeLoadedContentType: contentDescription)
        }
    }

    private func observeWebViewValue<Value>(for keyPath: KeyPath<WKWebView, Value>, debounce: Int? = nil,
                                            onValueChanged: ((Value) -> Void)? = nil) {
        guard let webView = webView else { return }
        var publisher: AnyPublisher<Value, Never> = webView.publisher(for: keyPath).eraseToAnyPublisher()
        if let debounce = debounce {
            publisher = publisher.debounce(for: .milliseconds(debounce), scheduler: DispatchQueue.main).eraseToAnyPublisher()
        }
        return publisher
            .sink(receiveValue: onValueChanged ?? { [weak self] value in
                guard let self = self else { return }
                self.delegate?.webViewController(self, observedValueChangedFor: keyPath, value: value)
            })
            .store(in: &observersCancellables)
    }

    private func setupWebViewValuesObservers() {
        if !observersCancellables.isEmpty {
            observersCancellables.removeAll()
        }

        observeWebViewValue(for: \.url) { [weak self] value in
            self?.webViewURLValueChanged(value)
        }
        observeWebViewValue(for: \.hasOnlySecureContent)
        observeWebViewValue(for: \.serverTrust)
        observeWebViewValue(for: \.canGoBack)
        observeWebViewValue(for: \.canGoForward)
        observeWebViewValue(for: \.backForwardList)
    }

    private func setupContextDependentObservers() {
        contextDependentObserversCancellables.removeAll()
        contentDescription?.titlePublisher.sink { [weak self] value in
            guard let self = self else { return }
            self.delegate?.webViewController(self, observedValueChangedFor: \.title, value: value)
        }.store(in: &contextDependentObserversCancellables)

        contentDescription?.isLoadingPublisher.sink { [weak self] value in
            guard let self = self else { return }
            self.delegate?.webViewController(self, observedValueChangedFor: \.isLoading, value: value)
        }.store(in: &contextDependentObserversCancellables)

        contentDescription?.estimatedProgressPublisher.sink { [weak self] value in
            guard let self = self else { return }
            self.delegate?.webViewController(self, observedValueChangedFor: \.estimatedProgress, value: value)
        }.store(in: &contextDependentObserversCancellables)
    }

    fileprivate func updateWebViewContentDescriptionObserver(for url: URL) {
        guard let webView = webView else { return }
        NavigationRouter.browserContentDescription(for: url, webView: webView) { [weak self] newDescription in
            guard let self = self, self.contentDescription?.type != .web || newDescription.type != .web else {
                return // web content is always the same. no need to update observers.
            }
            self.contentDescription = newDescription
            self.setupContextDependentObservers()
        }
    }

    private var previousWebViewURL: URL?
    private func webViewURLValueChanged(_ url: URL?) {
        guard let webviewUrl = url else {
            return // webview probably failed to load
        }
        // For security reason, we shoud only update the URL right away when the new one is from same origin.
        // Otherwise we can wait and URL will be updated in when `didReachURL` is called
        // https://github.com/mozilla-mobile/firefox-ios/wiki/WKWebView-navigation-and-security-considerations#single-page-js-apps-spas
        if let previousWebViewURL = previousWebViewURL, webviewUrl.isSameOrigin(as: previousWebViewURL) {
            delegate?.webViewController(self, didChangeDisplayURL: webviewUrl)
        }
        previousWebViewURL = webviewUrl
    }

    fileprivate func sendWebViewChangeURL(_ url: URL) {
        previousWebViewURL = url
        delegate?.webViewController(self, didChangeDisplayURL: url)
    }

    // MARK: - Navigation handling
    private var previousBackForwardUrlTriplet: BackForwardURLTriplet?
    fileprivate func handleBackForwardAction(navigationAction: WKNavigationAction) {
        guard let webView = navigationAction.targetFrame?.webView ?? navigationAction.sourceFrame.webView else {
            fatalError("Should emit handleBackForwardAction() from a webview")
        }
        switch getNavigationDirection(webView: webView) {
        case .historyForward:
            delegate?.webViewController(self, willMoveInHistory: true)
        case .historyBackward:
            delegate?.webViewController(self, willMoveInHistory: false)
        default:
            return
        }
    }
}

// MARK: - Navigation Handling
enum WebViewControllerNavigationSource: Equatable {
    enum JavacriptEvent: String {
        case popState = "popstate"
        case replaceState = "replaceState"
        case pushState = "pushState"
    }

    case webKit
    case javascript(event: JavacriptEvent)
}

protocol WebViewNavigationHandler: AnyObject {

    /// the Beam UI is telling the webView to load a specific URL
    func webViewIsInstructedToLoadURLFromUI(_ url: URL)

    /// the webView is about to decide whether it should perform the navigation action or not.
    func webView(_ webView: WKWebView, willPerformNavigationAction action: WKNavigationAction)

    /// the webView reached a new url.
    /// It started to receive content but is not finished yet
    func webView(_ webView: WKWebView, didReachURL url: URL)

    /// the webView reached a new url.
    /// It started to receive content but is not finished yet
    func webView(_ webView: WKWebView, didFinishNavigationToURL url: URL, source: WebViewControllerNavigationSource)
}

extension WebViewController: WebViewNavigationHandler {

    func webViewIsInstructedToLoadURLFromUI(_ url: URL) {
        requestedURL = url
        lastNavigationWasTriggeredByBeamUI = true
    }

    func webView(_ webView: WKWebView, didReachURL url: URL) {
        updateWebViewContentDescriptionObserver(for: url)

        // should call self.delegate?.didChangeDisplayURL(webviewUrl)
        // but for now the webView.didCommit(:) does it for us.

        var finalURL = url
        if BeamURL(url).isErrorPage {
            let beamSchemeUrl = BeamURL(url)
            finalURL = beamSchemeUrl.originalURLFromErrorPage ?? beamSchemeUrl.url

            if let extractedCode = BeamURL.getQueryStringParameter(url: beamSchemeUrl.url.absoluteString, param: "code"),
               let errorCode = Int(extractedCode),
               let errorUrl = self.page?.url {
                self.page?.errorPageManager = .init(errorCode, webView: webView,
                                                    errorUrl: errorUrl,
                                                    defaultLocalizedDescription: BeamURL.getQueryStringParameter(url: beamSchemeUrl.url.absoluteString, param: "localizedDescription"))
            }

        } else {
            // Present the original, non-internal URL
            finalURL = NavigationRouter.originalURL(internal: url)
        }
        sendWebViewChangeURL(finalURL)
        delegate?.webViewControllerIsNavigatingToANewPage(self)
    }

    func webView(_ webView: WKWebView, willPerformNavigationAction action: WKNavigationAction) {
        switch action.navigationType {
        case .other:
            // this is a redirect, we keep the requested url as is to update its title once the actual destination is reached
            return
        case .formSubmitted, .formResubmitted:
            // We found at that `action.sourceFrame` can be null for `.formResubmitted` even if it's not an optional
            // Assigning it to an optional to check if we have a value
            // see https://linear.app/beamapp/issue/BE-3180/exc-breakpoint-exception-6-code-3431810664-subcode-8
            let sourceFrame: WKFrameInfo? = action.sourceFrame
            if let sourceFrame = sourceFrame {
                Logger.shared.logDebug("Form submitted for \(sourceFrame.request.url?.absoluteString ?? "(no source frame URL)")", category: .web)
                page?.handleFormSubmit(frameInfo: sourceFrame)
            }
        case .backForward:
            handleBackForwardAction(navigationAction: action)
        default:
            break
        }

        lastNavigationWasTriggeredByBeamUI = false
        Logger.shared.logInfo("Nav Redirecting toward: \(action.request.url?.absoluteString ?? "nilURL"), type:\(action.navigationType)",
                              category: .web)
        // update the requested url as it is not from a redirection but from a user action:
        if let url = action.request.url {
            self.requestedURL = url
        }
    }

    func webView(_ webView: WKWebView, didFinishNavigationToURL url: URL, source: WebViewControllerNavigationSource) {
        //on gmail.com clicking in the app triggers a popState event
        //on drive.google.com hitting back triggers a replaceState
        //so we need compare backForwardList evolution to disambiguate between goForward, navigateTo and goBack
        var keepSameParent = false
        if case .javascript(event: _) = source {
            switch getNavigationDirection(webView: webView) {
            case .historyBackward:
                delegate?.webViewController(self, willMoveInHistory: false)
                return
            case .historyForward:
                delegate?.webViewController(self, willMoveInHistory: true)
                return
            case .navigateToPageSameParent:
                keepSameParent = true
            default:
                break
            }
        }

        // If the webview is loading, we should not index the content.
        // We will be called by the webView delegate at the end of the loadin
        guard !webView.isLoading else { return }

        // Only register navigation if the page was successfully loaded
        guard self.page?.responseStatusCode == 200 else { return }

        var isJSPush = false
        var isLinkActivation = !lastNavigationWasTriggeredByBeamUI
        if case .javascript(let event) = source {

            let replacing = event == .replaceState
            isJSPush = !replacing
            isLinkActivation = isLinkActivation && !replacing
        }

        var requestedURL = self.requestedURL
        // if we receive a navigation less than 500ms after the previous one,
        // and it's not a user interaction (no requestedURL)
        // then consider this as a redirect that the website was just too slow to trigger.
        if requestedURL == nil, !isJSPush, let previousNav = lastNavigationFinished,
           previousNav.time.timeIntervalSinceNow > -maxTimeSinceLastNavigationForRedirection {
            requestedURL = previousNav.requestedURL
        }
        let description = WebViewNavigationDescription(url: url, source: source, isLinkActivation: isLinkActivation,
                                                       requestedURL: requestedURL, keepSameParent: keepSameParent)
        lastNavigationFinished = description
        lastNavigationWasTriggeredByBeamUI = false
        previousBackForwardUrlTriplet = BackForwardURLTriplet(list: webView.backForwardList)

        self.requestedURL = nil

        delegate?.webViewController(self, didFinishNavigatingToPage: description)
    }

    private enum NavigationDirection {
        case historyForward
        case historyBackward
        case navigateToPage
        case navigateToPageSameParent //mostly in case of javascript replace state
    }

    @discardableResult
    private func getNavigationDirection(webView: WKWebView) -> NavigationDirection {
        defer { self.previousBackForwardUrlTriplet = BackForwardURLTriplet(list: webView.backForwardList) }
        guard let previousBackForwardUrlTriplet = previousBackForwardUrlTriplet else { return .navigateToPage }

        if previousBackForwardUrlTriplet.currentUrl == webView.backForwardList.backItem?.url {
            if previousBackForwardUrlTriplet.forwardUrl == webView.backForwardList.currentItem?.url {
                return .historyForward
            } else {
                return .navigateToPage
            }
        }
        if previousBackForwardUrlTriplet.currentUrl == webView.backForwardList.forwardItem?.url {
            return .historyBackward
        }
        if previousBackForwardUrlTriplet.backUrl == webView.backForwardList.backItem?.url,
           previousBackForwardUrlTriplet.currentUrl != webView.backForwardList.currentItem?.url {
            return .navigateToPageSameParent
        }
        return .navigateToPage
    }
}
