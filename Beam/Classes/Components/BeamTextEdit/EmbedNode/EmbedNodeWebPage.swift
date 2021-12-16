//
//  EmbedNodeWebPage.swift
//  Beam
//
//  Created by Remi Santos on 02/07/2021.
//

import Foundation

protocol EmbedNodeWebPageDelegate: AnyObject {
    func embedNodeDidUpdateMediaController(_ controller: MediaPlayerController?)
    func embedNodeDelegateCallback(size: CGSize)
}

class EmbedNodeWebPage: WebPageBaseImpl {
    weak var delegate: EmbedNodeWebPageDelegate?

    override var mediaPlayerController: MediaPlayerController? {
        didSet {
            delegate?.embedNodeDidUpdateMediaController(mediaPlayerController)
        }
    }

    override init(webView: BeamWebView) {
        super.init(webView: webView)
        self.mediaPlayerController = MediaPlayerController(page: self)
    }
}
