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

    weak var webView: BeamWebView!

    init(webView: BeamWebView) {
        self.webView = webView
    }

    var downloadManager: DownloadManager?
    var webviewWindow: NSWindow?
    var fileStorage: BeamFileStorage?

    var frame: NSRect = .zero
    var scrollX: CGFloat = .zero
    var scrollY: CGFloat = .zero
    var originalQuery: String?
    var pointAndShootAllowed: Bool = false

    var title: String = ""
    var url: URL?

    var pointAndShoot: PointAndShoot?
    var navigationController: WebNavigationController?
    var browsingScorer: BrowsingScorer?
    var passwordOverlayController: PasswordOverlayController?
    var mediaPlayerController: MediaPlayerController?
    var appendToIndexer: ((URL, Readability) -> Void)?
    var score: Float = 0

    var authenticationViewModel: AuthenticationViewModel?
}
