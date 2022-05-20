//
//  WebPageBaseImpl.swift
//  Beam
//
//  Created by Remi Santos on 02/07/2021.
//

import Foundation

/**
 Base empty implementation of a WebPage

 Used to manage a single or few features of a webview
 */
class WebPageBaseImpl: WebPage {

    var webView: BeamWebView

    init(webView: BeamWebView) {
        self.webView = webView
    }

    var downloadManager: DownloadManager?
    var webviewWindow: NSWindow?
    var fileStorage: BeamFileStorage?

    var frame: NSRect = .zero
    var originalQuery: String?
    var pointAndShootInstalled: Bool = false
    var pointAndShootEnabled: Bool = false

    var title: String = ""
    var url: URL?
    var requestedURL: URL?
    var contentDescription: BrowserContentDescription?
    var hasError: Bool = false
    var responseStatusCode: Int = 200

    var pointAndShoot: PointAndShoot?
    var webFrames: WebFrames?
    var webPositions: WebPositions?
    var webViewNavigationHandler: WebViewNavigationHandler?
    var errorPageManager: ErrorPageManager?
    var browsingScorer: BrowsingScorer?
    var webAutofillController: WebAutofillController?
    var mediaPlayerController: MediaPlayerController?
    var score: Float = 0

    var authenticationViewModel: AuthenticationViewModel?
    var searchViewModel: SearchViewModel?
    var mouseHoveringLocation: MouseHoveringLocation = .none

}
