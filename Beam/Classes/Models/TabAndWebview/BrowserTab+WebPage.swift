//
//  BrowserTab+WebPage.swift
//  Beam
//
//  Created by Remi Santos on 06/01/2022.
//

import Foundation
import BeamCore

/// WebPage method implementations
extension BrowserTab: WebPage {

    // MARK: - Note handling
    /// Add provided BeamElements to the Destination Note. If a source is provided, the content will be added
    /// underneath the source url. A new source url will be created if non exists yet.
    /// - Parameters:
    ///   - content: An array of BeamElement to add
    ///   - source: The source url of where content was added from.
    ///   - reason: Reason to create BeamElement
    /// - Returns: The BeamElement where content was added to. (discardable)
    func addContent(content: [BeamElement], with source: URL? = nil, reason: NoteElementAddReason) {
        Task.detached(priority: .background) { [weak self] in
            await self?.noteController.addContent(content: content, with: source, title: self?.title, reason: reason)
        }
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        noteController.setDestination(note: note, rootElement: rootElement)
        state?.destinationCardName = note.title
        state?.recentsManager.currentNoteChanged(note)
        browsingTree.destinationNoteChange()
    }

    /// Calls BeamNote to fetch a note from the documentManager
    /// - Parameter noteTitle: The title of the Note
    /// - Returns: The fetched note or nil if no note exists
    func getNote(fromTitle noteTitle: String) -> BeamNote? {
        return BeamNote.fetch(title: noteTitle)
    }

    // MARK: Tab handling
    private func createNewTab(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, state: BeamState, rect: NSRect) -> WebPage {
        let newWebView = BeamWebView(frame: rect, configuration: configuration ?? Self.webViewConfiguration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let origin = BrowsingTreeOrigin.browsingNode(
            id: browsingTree.current.id,
            pageLoadId: browsingTree.current.events.last?.pageLoadId,
            rootOrigin: browsingTree.origin.rootOrigin,
            rootId: browsingTree.rootId
        )
        let newTab = state.addNewTab(
            origin: origin,
            setCurrent: setCurrent,
            note: noteController.note,
            element: isFromNoteSearch ? noteController.element : nil,
            request: request,
            webView: newWebView
        )
        newTab.browsingTree.current.score.openIndex = numberOfLinksOpenedInANewTab
        numberOfLinksOpenedInANewTab += 1
        browsingTree.openLinkInNewTab()
        return newTab
    }

    func createNewTab(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, rect: NSRect) -> WebPage? {
        guard let state = state else { return nil }
        if let currentTab = state.browserTabsManager.currentTab, !currentTab.isPinned && !setCurrent && state.browserTabsManager.currentTabNeighborhoodKey != currentTab.id {
            state.browserTabsManager.removeFromTabNeighborhood(tabId: currentTab.id)
            state.browserTabsManager.createNewNeighborhood(for: currentTab.id)
        }
        return createNewTab(request, configuration, setCurrent: setCurrent, state: state, rect: rect)
    }

    func createNewWindow(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        let defaultValue = true
        let menubar = windowFeatures.menuBarVisibility?.boolValue ?? defaultValue
        let statusBar = windowFeatures.statusBarVisibility?.boolValue ?? defaultValue
        let toolBars = windowFeatures.toolbarsVisibility?.boolValue ?? defaultValue
        let resizing = windowFeatures.allowsResizing?.boolValue ?? defaultValue

        var newWebView: BeamWebView
        var newWindow: NSWindow
        if menubar && statusBar && toolBars && resizing,
           let newBeamWindow = AppDelegate.main.createWindow(frame: windowFeatures.toRect()) {
            // we are being asked for the full browser experience, give it to them...
            let tab = createNewTab(
                request,
                configuration,
                setCurrent: setCurrent,
                state: newBeamWindow.state,
                rect: windowFeatures.toRect()
            )

            newWindow = newBeamWindow
            newWebView = tab.webView
            if let windowFeatures = windowFeatures as? BeamWindowFeatures {
                windowFeatures.origin = newBeamWindow.frame.origin
            }
        } else {
            // this is more likely a login window or something that should disappear at some point so let's create something transient:
            // IMPORTANT!!: WebKit will perform the `URLRequest` automatically!! Attempting to do
            // the request here manually leads to incorrect results!!
            // source: https://github.com/ghostery/user-agent-ios/blob/61126a96930553d9d9ac5eae3503d17fe586fafe/Client/Frontend/Browser/BrowserViewController/BrowserViewController+WebViewDelegates.swift#L30-L33
            let transientWebViewWindow = TransientWebViewWindow(originPage: self, request: request, configuration: configuration, windowFeatures: windowFeatures)
            transientWebViewWindow.makeKeyAndOrderFront(nil)
            newWindow = transientWebViewWindow
            newWebView = transientWebViewWindow.webView
            state?.setup(webView: newWebView)
        }
        if windowFeatures.x == nil || windowFeatures.y == nil {
            if let beamWindowFeatures = windowFeatures as? BeamWindowFeatures, beamWindowFeatures.origin == nil {
                newWindow.center()
            }
        }
        return newWebView
    }

    func tabWillClose() {
        cancelObservers()

        // Keep the web view alive until after the beforeunload event is processed.
        let webView = self.webView
        webView.evaluateJavaScript(#"window.dispatchEvent(new Event("beforeunload"))"#) { result, error in
            _ = webView
        }
        
        isFromNoteSearch = false
        webAutofillController?.dismiss()
        authenticationViewModel?.cancel()
        browsingTree.closeTab()
        saveTree()
        sendTree()
        state?.webIndexingController?.tabDidClose(self)
        if !(webviewWindow is BeamWindow) && webviewWindow?.styleMask.contains(.fullScreen) == true {
            // Webview is in fullscreen, we need to manually dismiss it to prevent crash in WKFullScreenWindowController
            // See https://linear.app/beamapp/issue/BE-1810/exc-bad-access-exception-1-code-47767648-subcode-8
            webviewWindow?.windowController?.close()
        }
    }

    func getMouseLocation() -> NSPoint {
        let webviewCenter = CGPoint(
            x: webView.frame.midX - (PointAndShootView.defaultPickerSize.width / 2),
            y: webView.frame.midY - (PointAndShootView.defaultPickerSize.height / 2)
        )

        guard let pns = pointAndShoot else { return webviewCenter }

        if webView.frame.contains(pns.mouseLocation) && pns.mouseLocation != .zero {
            return pns.mouseLocation
        } else {
            return webviewCenter
        }
    }

    /// Handles collecting a full tab with CMD+S
    func collectTab() {

        guard let layer = webView.layer,
              let url = url,
              let pns = pointAndShoot
        else { return }

        let animator = FullPageCollectAnimator(webView: webView)
        guard let (hoverLayer, hoverGroup, webViewGroup) = animator.buildFullPageCollectAnimation() else { return }

        let mouseLocation = self.getMouseLocation()
        let remover = LayerRemoverAnimationDelegate(with: hoverLayer) { [weak self] _ in
            // Skip full page collect when the page has been collected previously
            guard pns.hasCollectedFullPage == false else { return }
            DispatchQueue.main.async {
                let target = PointAndShoot.Target.init(
                    id: UUID().uuidString,
                    rect: self?.webView.frame ?? .zero,
                    mouseLocation: mouseLocation,
                    html: "",
                    animated: true
                )

                let shootGroup = PointAndShoot.ShootGroup.init(
                    id: UUID().uuidString,
                    targets: [target],
                    showRect: false,
                    fullPageCollect: true
                )

                // If noteController has a destination note we can directly add to that note
                if let noteController = self?.noteController, let note = noteController.note {
                    pns.addSocialTitleToNote(noteController: noteController, note: note, sourceUrl: url, shootGroup: shootGroup)
                } else {
                    pns.activeShootGroup = shootGroup
                }
            }
        }
        hoverGroup.delegate = remover

        layer.superlayer?.addSublayer(hoverLayer)
        layer.add(webViewGroup, forKey: "animation")
        hoverLayer.add(hoverGroup, forKey: "hover")
    }

    func isActiveTab() -> Bool {
        self == state?.browserTabsManager.currentTab
    }

    // MARK: Navigation handling
    func shouldNavigateInANewTab(url: URL) -> Bool {
        return isPinned && self.url != nil && url.mainHost != self.url?.mainHost
    }

    /// When using Point and Shoot to capture text in a webpage, notify the
    /// clustering manager, so the important text can be taken into consideration
    /// in the clustering process
    ///
    /// - Parameters:
    ///   - text: The text that was captured, as a string. If possible - the cleaner the
    ///   better (the text shouldn't include the caption of a photo, for example). If no text was captured,
    ///   this function should not be called.
    ///   - url: The url of the page the PnS was performed in.
    ///
    func addTextToClusteringManager(_ text: String, url: URL) {
        let clusteringManager = state?.data.clusteringManager
        let id = browsingTree.current.link
        clusteringManager?.addPage(id: id, parentId: nil, value: nil, newContent: text)
    }

    // MARK: Mouse Interactions
    func allowsMouseMoved(with event: NSEvent) -> Bool {
        state?.omniboxInfo.isFocused == false || (state?.omniboxInfo.wasFocusedFromTab == true && state?.autocompleteManager.autocompleteResults.isEmpty == true)
    }
}
