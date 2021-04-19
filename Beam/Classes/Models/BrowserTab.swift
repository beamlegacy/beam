//
//  BrowserTab.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//
// swiftlint:disable file_length

import Foundation
import SwiftUI
import Combine
import WebKit
import BeamCore

class FullScreenWKWebView: WKWebView {
//    override var safeAreaInsets: NSEdgeInsets {
//        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }

    //Catching those event to avoid funk sound
    override func keyDown(with event: NSEvent) {
        if let key = event.specialKey {
            if key == .leftArrow || key == .rightArrow {
                return
            }
        }
        super.keyDown(with: event)
    }
}

struct FrameInfo {
    let origin: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

// swiftlint:disable:next type_body_length
class BrowserTab: NSView, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, Codable, WebPage {
    var id: UUID

    private(set) var scrollX: CGFloat = 0
    private(set) var scrollY: CGFloat = 0
    private var pixelRatio: Double = 1

    public func load(url: URL) {
        self.url = url
        navigationCount = 0
        webView.load(URLRequest(url: url))
        $isLoading.sink { [weak passwordOverlayController] loading in
            if !loading {
                passwordOverlayController?.detectInputFields()
            }
        }.store(in: &scope)
    }

    @Published public var webView: WKWebView! {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String = ""
    @Published var originalQuery: String?
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

    @Published var browsingTree: BrowsingTree
    @Published var privateMode = false

    lazy var pointAndShoot: PointAndShoot = {
        // Avoid instantiate if !pointAndShootEnabled
        PointAndShoot(page: self, ui: PointAndShootUI())
    }()

    lazy var passwordOverlayController: PasswordOverlayController = PasswordOverlayController(webView: webView)

    lazy var webPositions: WebPositions = WebPositions()

    var state: BeamState!

    public private(set) var note: BeamNote
    public private(set) var rootElement: BeamElement
    public private(set) var element: BeamElement?

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        self.note = note
        self.rootElement = rootElement ?? note
        self.note.browsingSessions.append(browsingTree)

        if let elem = element {
            // reparent the element that has alreay been created
            self.rootElement.addChild(elem)
        } else {
            _ = addCurrentPageToNote()
        }
    }

    var appendToIndexer: (URL, Readability) -> Void = { _, _ in
    }

    var creationDate: Date = Date()
    var lastViewDate: Date = Date()

    public var onNewTabCreated: (BrowserTab) -> Void = { _ in
    }

    private var scope = Set<AnyCancellable>()

    class var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.tabFocusesLinks = true
//        config.preferences.plugInsEnabled = true
        config.preferences._setFullScreenEnabled(true)
        config.preferences.isFraudulentWebsiteWarningEnabled = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        return config
    }

    init(state: BeamState, originalQuery: String?, note: BeamNote, rootElement: BeamElement? = nil, id: UUID = UUID(),
         webView: WKWebView? = nil, createBullet: Bool = true) {
        self.state = state
        self.id = id
        self.note = note
        self.rootElement = rootElement ?? note
        self.originalQuery = originalQuery

        if let suppliedWebView = webView {
            self.webView = suppliedWebView
            backForwardList = suppliedWebView.backForwardList
        } else {
            let web = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
            web.wantsLayer = true
            web.allowsMagnification = true

            state.setup(webView: web)
            backForwardList = web.backForwardList
            self.webView = web
        }

        browsingTree = BrowsingTree(originalQuery ?? webView?.url?.absoluteString)

        super.init(frame: .zero)
        note.browsingSessions.append(browsingTree)
        setupObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalQuery
        case url
        case browsingTree
        case privateMode
        case note
        case rootElement
        case element
    }

    var preloadUrl: URL?

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        originalQuery = try container.decode(String.self, forKey: .originalQuery)
        preloadUrl = try? container.decode(URL.self, forKey: .url)

        browsingTree = try container.decode(BrowsingTree.self, forKey: .browsingTree)
        privateMode = try container.decode(Bool.self, forKey: .privateMode)

        let noteTitle = try container.decode(String.self, forKey: .note)
        let loadedNote = BeamNote.fetch(AppDelegate.main.documentManager, title: noteTitle) ?? AppDelegate.main.data.todaysNote
        note = loadedNote
        let rootId = try? container.decode(UUID.self, forKey: .rootElement)
        rootElement = note.findElement(rootId ?? loadedNote.id) ?? loadedNote.children.first!
        if let elementId = try? container.decode(UUID.self, forKey: .element) {
            element = loadedNote.findElement(elementId)
        }

        super.init(frame: .zero)
        note.browsingSessions.append(browsingTree)
    }

    func postLoadSetup(state: BeamState) {
        self.state = state
        let web = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
        web.wantsLayer = true
        web.allowsMagnification = true

        state.setup(webView: web)
        backForwardList = web.backForwardList
        webView = web
//        setupObservers()
        if let suppliedPreloadURL = preloadUrl {
            preloadUrl = nil
            DispatchQueue.main.async { [weak self] in
                self?.webView.load(URLRequest(url: suppliedPreloadURL))
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(originalQuery, forKey: .originalQuery)
        if let currentURL = webView.url {
            try container.encode(currentURL, forKey: .url)
        }
        try container.encode(browsingTree, forKey: .browsingTree)
        try container.encode(privateMode, forKey: .privateMode)
        try container.encode(note.title, forKey: .note)
        try container.encode(rootElement.id, forKey: .rootElement)
        if let element = element {
            try container.encode(element, forKey: .element)
        }
    }

    // Add the current page to the current note and return the beam element
    // (if the element already exist return it directly)
    func addCurrentPageToNote(allowSearchResult: Bool = false) -> BeamElement? {
        guard let elem = element else {
            guard let url = self.url else {
                Logger.shared.logError("Cannot get current URL", category: .general)
                return nil
            }
            guard allowSearchResult || !url.isSearchResult else {
                Logger.shared.logWarning("Adding search results is not allowed", category: .web)
                return nil
            } // Don't automatically add search results
            let linkString = url.absoluteString
            guard !note.outLinks.contains(linkString) else {
                element = note.elementContainingLink(to: linkString); return element
            }
            Logger.shared.logDebug("add current page '\(title)' to note '\(note.title)'", category: .web)
            if rootElement.children.count == 1,
               let firstElement = rootElement.children.first,
               firstElement.text.isEmpty {
                element = firstElement
            } else {
                let newElement = BeamElement()
                element = newElement
                rootElement.addChild(newElement)
            }
            updateElementWithTitle()
            return element
        }
        return elem
    }

    private func receivedWebviewTitle(_ title: String? = nil) {
        updateElementWithTitle(title)
        guard title?.isEmpty == false || !isLoading else {
            return
        }
        self.title = title ?? ""
    }

    private func updateElementWithTitle(_ title: String? = nil) {
        if let url = url, let element = element {
            let name = title ?? (self.title.isEmpty ? url.absoluteString : self.title)
            element.text = BeamText(text: name, attributes: [.link(url.absoluteString)])
        }
    }

    private func updateFavIcon() {
        guard let url = url else { favIcon = nil; return }
        FaviconProvider.shared.imageForUrl(url) { [weak self] (image) in
            guard let self = self else { return }
            self.favIcon = image
        }
    }

    private func updateScore() {
        let score = browsingTree.current.score.score
//            Logger.shared.logDebug("updated score[\(url!.absoluteString)] = \(s)", category: .general)
        element?.score = score
        if score > 0.0 {
            _ = addCurrentPageToNote() // Automatically add current page to note over a certain threshold
        }
    }

    var backListSize = 0

    private func setupObservers() {
        Logger.shared.logInfo("setupObservers", category: .general)
        webView.publisher(for: \.title).sink { v in
            self.receivedWebviewTitle(v)
        }.store(in: &scope)
        webView.publisher(for: \.url).sink { value in
            self.url = value
            if value?.absoluteString != nil {
                self.updateFavIcon()
                // self.browsingTree.current.score.openIndex = self.navigationCount
                // self.updateScore()
                // self.navigationCount = 0
            }
        }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink { value in withAnimation { self.isLoading = value } }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink { value in
            withAnimation { self.estimatedProgress = value }
        }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent)
                .sink { value in self.hasOnlySecureContent = value }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink { value in self.serverTrust = value }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink { value in self.canGoBack = value }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink { value in self.canGoForward = value }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink { value in self.backForwardList = value }.store(in: &scope)

        webView.navigationDelegate = self
        webView.uiDelegate = self

        removeScriptHandlers()
        removeUserScripts()

        addScriptHandlers()
        addUserScripts()
    }

    func cancelObservers() {
        scope.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        removeScriptHandlers()
    }

    private func removeUserScripts() {
        webView.configuration.userContentController.removeAllUserScripts()
    }

    lazy var devTools: String = {
        loadFile(from: "DevTools", fileType: "js")
    }()

    private func addUserScripts() {
        addJS(source: overrideConsole, when: .atDocumentStart)
        pointAndShoot.injectScripts()
        addJS(source: jsPasswordManager, when: .atDocumentEnd)
        //    addJS(source: devTools, when: .atDocumentEnd)
    }

    private func obfuscate(parameterized: String) -> String {
        parameterized.replacingOccurrences(of: "__ID__",
                                           with: "beam" + id.uuidString.replacingOccurrences(of: "-", with: "_"))
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        let parameterized = source.replacingOccurrences(of: "__ENABLED__", with: "true")
        let obfuscated = obfuscate(parameterized: parameterized)
        let script = WKUserScript(source: obfuscated, injectionTime: when, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }

    func executeJS(objectName: String, jsCode: String) {
        let parameterized = "__ID__\(objectName)." + jsCode
        let obfuscatedCommand = obfuscate(parameterized: parameterized)
        webView.evaluateJavaScript(obfuscatedCommand) { (result, error) in
            if error == nil {
                Logger.shared.logInfo("(\(obfuscatedCommand) succeeded: \(String(describing: result))",
                                      category: .javascript)
            } else {
                Logger.shared.logError("(\(obfuscatedCommand) failed: \(String(describing: error))",
                                       category: .javascript)
            }
        }
    }

    private func encodeStringTo64(fromString: String) -> String? {
        let plainData = fromString.data(using: .utf8)
        return plainData?.base64EncodedString(options: [])
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        let styleSrc = """
                       var style = document.createElement('style');
                       style.innerHTML = `\(source)`;
                       document.head.appendChild(style);
                       """
        addJS(source: styleSrc, when: when)
    }

    private enum ScriptHandlers: String, CaseIterable {
        case beam_point
        case beam_shoot
        case beam_shootConfirmation
        case beam_textSelection
        case beam_textSelected
        case beam_onLoad
        case beam_onScrolled
        case beam_logging
        case beam_textInputFields
        case beam_textInputFocusIn
        case beam_textInputFocusOut
        case beam_resize
        case beam_pinch
        case beam_frameBounds
        case beam_setStatus
    }

    private func removeScriptHandlers() {
        ScriptHandlers.allCases.forEach {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    private func addScriptHandlers() {
        ScriptHandlers.allCases.forEach {
            let handler = $0.rawValue
            webView.configuration.userContentController.add(self, name: handler)
            Logger.shared.logDebug("Added Script handler: \(handler)", category: .web)
        }
    }

    private var currentBackForwardItem: WKBackForwardListItem?

    private func handleBackForwardWebView(navigationAction: WKNavigationAction) {
        if navigationAction.navigationType == .backForward {
            let isBack = webView.backForwardList.backList
                    .filter {
                $0 == currentBackForwardItem
            }
                    .count == 0

            if isBack {
                browsingTree.goBack()
            } else {
                browsingTree.goForward()
            }
        }
        pointAndShoot.removeAll()
        currentBackForwardItem = webView.backForwardList.currentItem
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        element = nil
        pointAndShoot.removeAll()
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        element = nil
        handleBackForwardWebView(navigationAction: navigationAction)
        if let targetURL = navigationAction.request.url {
            if navigationAction.modifierFlags.contains(.command) {
                // Create new tab
                let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: Self.webViewConfiguration)
                newWebView.wantsLayer = true
                newWebView.allowsMagnification = true

                state.setup(webView: newWebView)
                let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: note,
                                        rootElement: rootElement, webView: newWebView)
                newTab.load(url: targetURL)
                newTab.browsingTree.current.score.openIndex = navigationCount
                navigationCount += 1
                onNewTabCreated(newTab)
                decisionHandler(.cancel, preferences)
                browsingTree.switchToOtherTab()

                return
            }

            visitedURLs.insert(targetURL)
        }

        decisionHandler(.allow, preferences)
    }

    var navigationCount: Int = 0

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        element = nil
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        element = nil
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        element = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        element = nil
        Logger.shared.logError("didfail: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        element = nil
        _ = addCurrentPageToNote()
    }

    lazy var overrideConsole: String = {
        loadFile(from: "OverrideConsole", fileType: "js")
    }()
    lazy var jsPasswordManager: String = {
        loadFile(from: "PasswordManager", fileType: "js")
    }()

    func pointAndShootTargetValues(from jsMessage: [String: AnyObject]) -> (location: NSPoint, html: String)? {
        guard let html = jsMessage["html"] as? String,
              let location = jsMessage["location"] else {
            return nil
        }
        let position = webPositions.jsToPoint(jsPoint: location)
        return (position, html)
    }

    func pointAndShootAreaValue(from jsMessage: [String: AnyObject]) -> NSRect? {
        guard let area = jsMessage["area"] else {
            return nil
        }
        return webPositions.jsToRect(jsArea: area)
    }

    func pointAndShootAreasValue(from jsMessage: [String: AnyObject]) -> [NSRect]? {
        guard let areas = jsMessage["areas"] as? [AnyObject] else {
            return nil
        }
        return areas.map { webPositions.jsToRect(jsArea: $0) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? [String: AnyObject]
        let messageKey = message.name
        let messageName = messageKey //.components(separatedBy: "_beam_")[1]
        switch messageName {
        case ScriptHandlers.beam_logging.rawValue:
            guard let dict = messageBody,
                  let type = dict["type"] as? String,
                  let message = dict["message"] as? String
                    else {
                Logger.shared.logError("Ignored log event: \(String(describing: messageBody))",
                                       category: .web)
                return
            }
            if type == "error" {
                Logger.shared.logError(message, category: .javascript)
            } else if type == "warning" {
                Logger.shared.logWarning(message, category: .javascript)
            } else if type == "log" {
                Logger.shared.logInfo(message, category: .javascript)
            }

        case ScriptHandlers.beam_onLoad.rawValue:
            Logger.shared.logInfo("onLoad flushing frameInfo", category: .web)
            webPositions.framesInfo.removeAll()

        case ScriptHandlers.beam_point.rawValue:
            guard webView.url?.isSearchResult != true else { return }
            guard let dict = messageBody,
                  let origin = dict["origin"] as? String ?? originalQuery,
                  let area = pointAndShootAreaValue(from: dict),
                  let (location, html) = pointAndShootTargetValues(from: dict) else {
                pointAndShoot.unpoint()
                return
            }
            let pointArea = webPositions.viewportArea(area: area, origin: origin)
            let target = PointAndShoot.Target(area: pointArea, mouseLocation: location, html: html)
            pointAndShoot.point(target: target)
            Logger.shared.logInfo("Web block point: \(pointArea)", category: .web)

        case ScriptHandlers.beam_shoot.rawValue:
            guard webView.url?.isSearchResult != true else { return }
            guard let dict = messageBody,
                  let area = pointAndShootAreaValue(from: dict),
                  let (location, html) = pointAndShootTargetValues(from: dict),
                  let origin = dict["origin"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: messageBody))", category: .web)
                return
            }
            let target = PointAndShoot.Target(area: area, mouseLocation: location, html: html)
            pointAndShoot.shoot(targets: [target], origin: origin)
            Logger.shared.logInfo("Web shoot point: \(area)", category: .web)

        case ScriptHandlers.beam_shootConfirmation.rawValue:
            guard webView.url?.isSearchResult != true else { return }
            guard let dict = messageBody,
                  let area = pointAndShootAreaValue(from: dict),
                  // let (location, html) = pointAndShootTargetValues(from: dict),
                  let _ = dict["origin"] as? String else {
                Logger.shared.logError("Ignored shoot event: \(String(describing: messageBody))", category: .web)
                return
            }
            // let target = PointAndShoot.Target(area: area, mouseLocation: location, html: html)
            pointAndShoot.showShootInfo(group: pointAndShoot.currentGroup!)
            Logger.shared.logInfo("Web shoot confirmation: \(area)", category: .web)

        case ScriptHandlers.beam_textSelected.rawValue:
            guard webView.url?.isSearchResult != true else { return }
            guard let dict = messageBody,
                  dict["index"] as? Int != nil,
                  dict["text"] as? String != nil,
                  let origin = dict["origin"] as? String,
                  let html = dict["html"] as? String,
                  let areas = pointAndShootAreasValue(from: dict),
                  !html.isEmpty else {
                Logger.shared.logError("Ignored text selected event: \(String(describing: messageBody))",
                                       category: .web)
                return
            }
            let targets = areas.map {
                PointAndShoot.Target(area: $0, mouseLocation: CGPoint(x: $0.minX, y: $0.maxY), html: html)
            }
            pointAndShoot.shoot(targets: targets, origin: origin)

        case ScriptHandlers.beam_textSelection.rawValue:
            guard webView.url?.isSearchResult != true else { return }
            guard let dict = messageBody,
                  dict["index"] as? Int != nil,
                  dict["text"] as? String != nil,
                  let origin = dict["origin"] as? String,
                  let html = dict["html"] as? String,
                  let areas = pointAndShootAreasValue(from: dict),
                  !html.isEmpty
                    else {
                Logger.shared.logError("Ignored text selection event: \(String(describing: messageBody))",
                                       category: .web)
                return
            }
            let targets = areas.map { PointAndShoot.Target(area: $0, mouseLocation: CGPoint(x: $0.minX, y: $0.maxY), html: html) }
            pointAndShoot.shoot(targets: targets, origin: origin)

        case ScriptHandlers.beam_pinch.rawValue:
            guard let dict = messageBody,
                  (dict["offsetLeft"] as? CGFloat) != nil,
                  (dict["pageLeft"] as? CGFloat) != nil,
                  (dict["offsetTop"] as? CGFloat) != nil,
                  (dict["pageTop"] as? CGFloat) != nil,
                  (dict["width"] as? CGFloat) != nil,
                  (dict["height"] as? CGFloat) != nil,
                  let scale = dict["scale"] as? CGFloat
                    else {
                return
            }
            webPositions.scale = scale

        case ScriptHandlers.beam_onScrolled.rawValue:
            guard let dict = messageBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let _ = dict["origin"] as? String,
                  let scale = dict["scale"] as? CGFloat
                    else {
                Logger.shared.logError("Ignored scroll event: \(String(describing: messageBody))", category: .web)
                return
            }
            webPositions.scale = scale
            scrollX = x // nativeX(x: x, origin: origin)
            scrollY = y // nativeY(y: y, origin: origin)
            passwordOverlayController.updateScrollPosition(x: x, y: y, width: width, height: height)
            if (pointAndShoot.isPointing) {
                // Logger.shared.logDebug("scroll redraw because pointing", pointAndShoot)
                pointAndShoot.drawAllGroups()
            } else {
                Logger.shared.logDebug("scroll NOT redraw because pointing=\(pointAndShoot.status)", category: .pointAndShoot)
            }
            if width > 0, height > 0 {
                let currentScore = browsingTree.current.score
                currentScore.scrollRatioX = max(Float(x / width), currentScore.scrollRatioX)
                currentScore.scrollRatioY = max(Float(y / height), currentScore.scrollRatioY)
                currentScore.area = Float(width * height)
                updateScore()
            }
            Logger.shared.logDebug("Web Scrolled: \(scrollX), \(scrollY)", category: .web)

        case ScriptHandlers.beam_textInputFields.rawValue:
            guard let jsonString = message.body as? String else { break }
            passwordOverlayController.updateInputFields(with: jsonString)

        case ScriptHandlers.beam_textInputFocusIn.rawValue:
            guard let elementId = message.body as? String else { break }
            passwordOverlayController.updateInputFocus(for: elementId, becomingActive: true)

        case ScriptHandlers.beam_textInputFocusOut.rawValue:
            guard let elementId = message.body as? String else { break }
            passwordOverlayController.updateInputFocus(for: elementId, becomingActive: false)

        case ScriptHandlers.beam_frameBounds.rawValue:
            guard let dict = messageBody,
                  let jsFramesInfo = dict["frames"] as? NSArray
                    else {
                Logger.shared.logError("Ignored beam_frameBounds: \(String(describing: messageBody))", category: .web)
                return
            }
            for jsFrameInfo in jsFramesInfo {
                let d = jsFrameInfo as AnyObject
                let bounds = d["bounds"] as AnyObject
                if let origin = d["origin"] as? String,
                   let href = d["href"] as? String {
                    webPositions.registerOrigin(origin: origin)
                    let rectArea = webPositions.jsToRect(jsArea: bounds)
                    let nativeBounds = webPositions.viewportArea(area: rectArea, origin: origin)
                    webPositions.framesInfo[href] = FrameInfo(
                            origin: origin, x: nativeBounds.minX, y: nativeBounds.minY,
                            width: nativeBounds.width, height: nativeBounds.height
                    )
                }
            }

        case ScriptHandlers.beam_resize.rawValue:
            guard let dict = messageBody,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let origin = dict["origin"] as? String
                    else {
                Logger.shared.logError("Ignored beam_resize: \(String(describing: messageBody))", category: .web)
                return
            }
            // pointAndShoot.drawCurrentGroup()
            passwordOverlayController.updateViewSize(width: width, height: height)

        case ScriptHandlers.beam_setStatus.rawValue:
            guard let dict = messageBody,
                  let status = dict["status"] as? String,
                  let _ = dict["origin"] as? String
                    else {
                Logger.shared.logError("Ignored beam_status: \(String(describing: messageBody))", category: .web)
                return
            }
            pointAndShoot.status = PointAndShootStatus(rawValue: status)!

        default:
            break
        }
    }

    func addSelectionToNote(noteTitle: String, target: PointAndShoot.Target,
                            withNote additionalText: String? = nil) throws {
        guard let url = webView.url,
              let note = BeamNote.fetch(state.data.documentManager, title: noteTitle)
                else { return }
        state.destinationCardName = note.title
        setDestinationNote(note, rootElement: note)
        let html = target.html
        let text: BeamText = html2Text(url: url, html: html)
        browsingTree.current.score.textSelections += 1
        updateScore()

        // now add a bullet point with the quoted text:
        guard let title = webView.title else { return }
        let urlString = url.absoluteString
        var quote = text
        quote.addAttributes([.emphasis], to: quote.wholeRange)

        DispatchQueue.main.async {
            guard let current = self.addCurrentPageToNote(allowSearchResult: true) else {
                Logger.shared.logError("Ignored current note add", category: .general)
                return
            }
            var quoteParent = current
            if let additionalText = additionalText, !additionalText.isEmpty {
                let quoteElement = BeamElement()
                quoteElement.kind = .quote(1, title, urlString)
                quoteElement.text = BeamText(text: additionalText, attributes: [])
                quoteElement.query = self.originalQuery
                current.addChild(quoteElement)
                quoteParent = quoteElement
            }
            let quoteE = BeamElement()
            quoteE.kind = .quote(1, title, urlString)
            quoteE.text = quote
            quoteE.query = self.originalQuery
            quoteParent.addChild(quoteE)
        }
        let noteInfo = NoteInfo(id: note.id, title: note.title)
        try pointAndShoot.complete(target: target, noteInfo: noteInfo)
    }

    func cancelShoot() {
        pointAndShoot.resetStatus()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        _ = addCurrentPageToNote()
        browsingTree.navigateTo(url: url.absoluteString, title: webView.title)
        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(read):
                self.appendToIndexer(url, read)
                self.updateElementWithTitle(webView.title)
                self.browsingTree.current.score.textAmount = read.content.count
                self.updateScore()
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .javascript)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        element = nil
        Logger.shared.logError("Webview failed: \(error)", category: .javascript)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }

    // WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let newWebView = FullScreenWKWebView(frame: NSRect(), configuration: configuration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let newTab = BrowserTab(state: state, originalQuery: originalQuery, note: note, rootElement: rootElement,
                                webView: newWebView)
        onNewTabCreated(newTab)

        return newTab.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Logger.shared.logDebug("webView runJavaScriptAlertPanelWithMessage \(message)", category: .web)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptConfirmPanelWithMessage \(message)", category: .web)
        completionHandler(true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptTextInputPanelWithPrompt \(prompt) default: \(defaultText ?? "")",
                               category: .web)
        completionHandler(nil)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        Logger.shared.logDebug("webView runOpenPanel", category: .web)
        completionHandler(nil)
    }

    func startReading() {
        lastViewDate = Date()
        browsingTree.startReading()
    }

    func switchToCard() {
        browsingTree.switchToCard()
    }

    func switchToOtherTab() {
        browsingTree.switchToOtherTab()
    }

    func switchToNewSearch() {
        browsingTree.switchToNewSearch()
    }

    func goBack() {
        browsingTree.goBack()
        webView.goBack()
    }

    func goForward() {
        browsingTree.goForward()
        webView.goForward()
    }

    func switchToBackground() {
        browsingTree.switchToBackground()
    }
}
