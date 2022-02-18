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

    // MARK: Note handling
    func addToNote(allowSearchResult: Bool, inSourceBullet: Bool = true) -> BeamElement? {
        guard let url = url else {
            Logger.shared.logError("Cannot get current URL", category: .general)
            return nil
        }
        guard allowSearchResult || SearchEngineProvider.provider(for: url) != nil else {
            Logger.shared.logWarning("Adding search results is not allowed", category: .web)
            return nil
        } // Don't automatically add search results

        if inSourceBullet {
            let element = noteController.addContent(url: url, text: title, reason: .pointandshoot)
            return element
        } else {
            let element = noteController.note
            return element
        }
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement? = nil) {
        noteController.setDestination(note: note, rootElement: rootElement)
        state?.destinationCardName = note.title
        browsingTree.destinationNoteChange()
    }

    /// Calls BeamNote to fetch a note from the documentManager
    /// - Parameter noteTitle: The title of the Note
    /// - Returns: The fetched note or nil if no note exists
    func getNote(fromTitle noteTitle: String) -> BeamNote? {
        return BeamNote.fetch(title: noteTitle)
    }

    // MARK: Tab handling
    private func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, state: BeamState) -> WebPage {
        let newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
        newWebView.wantsLayer = true
        newWebView.allowsMagnification = true

        state.setup(webView: newWebView)
        let origin = BrowsingTreeOrigin.browsingNode(
            id: browsingTree.current.id,
            pageLoadId: browsingTree.current.events.last?.pageLoadId,
            rootOrigin: browsingTree.origin.rootOrigin,
            rootId: browsingTree.rootId
        )
        let newTab = state.addNewTab(origin: origin, setCurrent: setCurrent,
                                     note: noteController.note, element: beamNavigationController?.isNavigatingFromNote == true ? noteController.element : nil,
                                     url: targetURL, webView: newWebView)
        newTab.browsingTree.current.score.openIndex = navigationCount
        navigationCount += 1
        browsingTree.openLinkInNewTab()
        return newTab
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage? {
        guard let state = state else { return nil }
        if let currentTab = state.browserTabsManager.currentTab, !currentTab.isPinned && !setCurrent && state.browserTabsManager.currentTabGroupKey != currentTab.id {
            state.browserTabsManager.removeFromTabGroup(tabId: currentTab.id)
            state.browserTabsManager.createNewGroup(for: currentTab.id)
        }
        return createNewTab(targetURL, configuration, setCurrent: setCurrent, state: state)
    }

    func createNewWindow(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        // TODO: Open a new window compliant with windowFeatures instead.
        let defaultValue = true
        let menubar = windowFeatures.menuBarVisibility?.boolValue ?? defaultValue
        let statusBar = windowFeatures.statusBarVisibility?.boolValue ?? defaultValue
        let toolBars = windowFeatures.toolbarsVisibility?.boolValue ?? defaultValue
        let resizing = windowFeatures.allowsResizing?.boolValue ?? defaultValue

        let x = windowFeatures.x?.floatValue ?? 0
        let y = windowFeatures.y?.floatValue ?? 0
        let width = windowFeatures.width?.floatValue ?? Float(webviewWindow?.frame.width ?? 800)
        let height = windowFeatures.height?.floatValue ?? Float(webviewWindow?.frame.height ?? 600)
        let windowFrame = NSRect(x: x, y: y, width: width, height: height)

        var newWebView: BeamWebView
        var newWindow: NSWindow
        if menubar && statusBar && toolBars && resizing, let newBeamWindow = AppDelegate.main.createWindow(frame: windowFrame, restoringTabs: false) {
            // we are being asked for the full browser experience, give it to them...
            let tab = createNewTab(targetURL, configuration, setCurrent: setCurrent, state: newBeamWindow.state)
            newWindow = newBeamWindow
            newWebView = tab.webView
        } else {
            // this is more likely a login window or something that should disappear at some point so let's create something transient:
            newWebView = BeamWebView(frame: NSRect(), configuration: configuration ?? Self.webViewConfiguration)
            newWebView.enableAutoCloseWindow = true
            newWebView.wantsLayer = true
            newWebView.allowsMagnification = true
            state?.setup(webView: newWebView)

            var windowMasks: NSWindow.StyleMask = [.closable, .miniaturizable, .titled, .unifiedTitleAndToolbar]
            if windowFeatures.allowsResizing != 0 {
                windowMasks.insert(NSWindow.StyleMask.resizable)
            }
            newWindow = NSWindow(contentRect: windowFrame, styleMask: windowMasks, backing: .buffered, defer: true)
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = newWebView
            newWindow.makeKeyAndOrderFront(nil)
        }
        if windowFeatures.x == nil || windowFeatures.y == nil {
            newWindow.center()
        }
        return newWebView
    }

    func closeTab() {
        isFromNoteSearch = false
        beamNavigationController?.isNavigatingFromNote = false
        passwordOverlayController?.dismiss()
        authenticationViewModel?.cancel()
        browsingTree.closeTab()
        saveTree()
        sendTree()
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
        let pageTitle = self.title.isEmpty ? url.absoluteString : self.title

        let remover = LayerRemoverAnimationDelegate(with: hoverLayer) { [weak self] _ in
            DispatchQueue.main.async {
                let target = PointAndShoot.Target.init(
                    id: UUID().uuidString,
                    rect: self?.webView.frame ?? .zero,
                    mouseLocation: mouseLocation,
                    html: "<a href=\"\(url)\">\(pageTitle)</a>",
                    animated: true
                )

                let shootGroup = PointAndShoot.ShootGroup.init(
                    id: UUID().uuidString,
                    targets: [target],
                    text: "",
                    href: "",
                    shapeCache: nil,
                    showRect: false,
                    directShoot: true
                )

                if let note = self?.noteController.note {
                    pns.addShootToNote(targetNote: note, withNote: nil, group: shootGroup, withSourceBullet: false, completion: {})
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
    func leave() {
        pointAndShoot?.leavePage()
        mouseHoveringLocation = .none
        cancelSearch()
    }

    func shouldNavigateInANewTab(url: URL) -> Bool {
        return isPinned && self.url != nil && url.mainHost != self.url?.mainHost
    }

    func navigatedTo(url: URL, title: String?, reason: NoteElementAddReason) {
        if case .searchFromNode = browsingTreeOrigin {
            logInNote(url: url, title: title, reason: reason)
        }
        updateScore()
        updateFavIcon(fromWebView: true)
        if reason == .navigation {
            pointAndShoot?.leavePage()
        }
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
        clusteringManager?.addPage(id: id, parentId: nil, newContent: text)
    }

    // MARK: Mouse Interactions
    func allowsMouseMoved(with event: NSEvent) -> Bool {
        state?.focusOmniBox == false || (state?.focusOmniBoxFromTab == true && state?.autocompleteManager.autocompleteResults.isEmpty == true)
    }
}
