//
//  BrowserTab+WebExtension.swift
//  Beam
//

import Foundation
import WebKit

// MARK: - Tabs

@available(macOS 15.4, *)
extension BrowserTab: WKWebExtensionTab {

    private var beamWindow: BeamWindow? {
        state?.associatedWindow as? BeamWindow
    }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        beamWindow
    }

    func indexInWindow(for context: WKWebExtensionContext) -> Int {
        state?.browserTabsManager.tabs.firstIndex(of: self) ?? NSNotFound
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        webView
    }

    func title(for context: WKWebExtensionContext) -> String? {
        title
    }

    func url(for context: WKWebExtensionContext) -> URL? {
        url
    }

    func pendingURL(for context: WKWebExtensionContext) -> URL? {
        isLoading ? preloadUrl : nil
    }

    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        !isLoading
    }

    func isPinned(for context: WKWebExtensionContext) -> Bool {
        isPinned
    }

    func setPinned(_ pinned: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        if let tabsManager = state?.browserTabsManager, pinned != isPinned {
            pinned ? tabsManager.pinTab(self) : tabsManager.unpinTab(self)
        }
        completionHandler(nil)
    }

    func isPlayingAudio(for context: WKWebExtensionContext) -> Bool {
        mediaPlayerController?.isPlaying ?? false
    }

    func isMuted(for context: WKWebExtensionContext) -> Bool {
        mediaPlayerController?.isMuted ?? false
    }

    func setMuted(_ muted: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        mediaPlayerController?.setMuted(muted)
        completionHandler(nil)
    }

    func size(for context: WKWebExtensionContext) -> CGSize {
        webView.frame.size
    }

    func zoomFactor(for context: WKWebExtensionContext) -> Double {
        webView.pageZoom
    }

    func setZoomFactor(_ zoomFactor: Double, for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        webView.pageZoom = zoomFactor
        completionHandler(nil)
    }

    func loadURL(_ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        load(request: URLRequest(url: url))
        completionHandler(nil)
    }

    func reload(fromOrigin: Bool, for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        if fromOrigin {
            webView.reloadFromOrigin()
        } else {
            reload()
        }
        completionHandler(nil)
    }

    func goBack(for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        goBack()
        completionHandler(nil)
    }

    func goForward(for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        goForward()
        completionHandler(nil)
    }

    func activate(for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        guard let state = state else {
            completionHandler(nil)
            return
        }
        state.browserTabsManager.setCurrentTab(self)
        state.mode = .web
        beamWindow?.makeKeyAndOrderFront(nil)
        completionHandler(nil)
    }

    func isSelected(for context: WKWebExtensionContext) -> Bool {
        state?.browserTabsManager.currentTab === self
    }

    func duplicate(using configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext,
                   completionHandler: @escaping ((any WKWebExtensionTab)?, (any Swift.Error)?) -> Void) {
        let tab = WebExtensionsManager.shared.openTab(with: url, in: (configuration.window as? BeamWindow) ?? beamWindow,
                                                      active: configuration.shouldBeActive)
        completionHandler(tab, nil)
    }

    func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        if let state = state, let index = state.browserTabsManager.tabs.firstIndex(of: self) {
            state.closeTab(index, allowClosingPinned: true)
        }
        completionHandler(nil)
    }

    func takeSnapshot(using configuration: WKSnapshotConfiguration, for context: WKWebExtensionContext,
                      completionHandler: @escaping (NSImage?, (any Swift.Error)?) -> Void) {
        webView.takeSnapshot(with: configuration, completionHandler: completionHandler)
    }
}

// MARK: - Windows

@available(macOS 15.4, *)
extension BeamWindow: WKWebExtensionWindow {

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        state.browserTabsManager.tabs
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        state.browserTabsManager.currentTab
    }

    func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType {
        .normal
    }

    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState {
        if isMiniaturized {
            return .minimized
        } else if state.isFullScreen {
            return .fullscreen
        } else if isZoomed {
            return .maximized
        }
        return .normal
    }

    func setWindowState(_ windowState: WKWebExtension.WindowState, for context: WKWebExtensionContext,
                        completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        switch windowState {
        case .minimized:
            miniaturize(nil)
        case .fullscreen:
            if !state.isFullScreen { toggleFullScreen(nil) }
        case .maximized:
            if isMiniaturized { deminiaturize(nil) }
            if !isZoomed { zoom(nil) }
        case .normal:
            if isMiniaturized { deminiaturize(nil) }
            if state.isFullScreen { toggleFullScreen(nil) }
        @unknown default:
            break
        }
        completionHandler(nil)
    }

    func isPrivate(for context: WKWebExtensionContext) -> Bool {
        state.isIncognito
    }

    func screenFrame(for context: WKWebExtensionContext) -> CGRect {
        screen?.frame ?? .null
    }

    func frame(for context: WKWebExtensionContext) -> CGRect {
        frame
    }

    func setFrame(_ frame: CGRect, for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        setFrame(frame, display: true, animate: false)
        completionHandler(nil)
    }

    func focus(for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        makeKeyAndOrderFront(nil)
        completionHandler(nil)
    }

    func close(for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        performClose(nil)
        completionHandler(nil)
    }
}
