//
//  MediaPlayerController.swift
//  Beam
//
//  Created by Remi Santos on 14/06/2021.
//

import Foundation

struct MediaPlayerController: WebPageRelated {

    private let JSObjectName = "MDPLR"
    private weak var _page: WebPage?
    var page: WebPage {
        get {
            guard let definedPage = _page else {
                fatalError("\(self) must have an associated WebPage")
            }
            return definedPage
        }
        set { _page = newValue }
    }

    var isPlaying = false
    var isMuted = false
    var isPiPSupported = true
    var isInPiP = false
    var frameInfo: WKFrameInfo?

    init(page: WebPage) {
        _page = page
    }

    mutating func toggleMute() {
        setMuted(!isMuted)
    }

    mutating func setMuted(_ muted: Bool) {
        if isMuted != muted {
            isMuted = muted
            page.executeJS("media_toggleMute()", objectName: JSObjectName, frameInfo: frameInfo)
        }
    }

    mutating func togglePiP() {
        isInPiP = !isInPiP
        page.executeJS("media_togglePictureInPicture()", objectName: JSObjectName, frameInfo: frameInfo)
    }
}
