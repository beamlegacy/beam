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
    var hasError: Bool = false
    var responseStatusCode: Int = 200

    var pointAndShoot: PointAndShoot?
    var webPositions: WebPositions?
    var navigationController: WebNavigationController?
    var errorPageManager: ErrorPageManager?
    var browsingScorer: BrowsingScorer?
    var passwordOverlayController: PasswordOverlayController?
    var mediaPlayerController: MediaPlayerController?
    var appendToIndexer: ((URL, _ title: String, Readability) -> Void)?
    var score: Float = 0

    var authenticationViewModel: AuthenticationViewModel?
    var searchViewModel: SearchViewModel?
    var mouseHoveringLocation: MouseHoveringLocation = .none

}
