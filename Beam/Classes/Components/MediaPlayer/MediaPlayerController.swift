//
//  MediaPlayerController.swift
//  Beam
//
//  Created by Remi Santos on 14/06/2021.
//

import Foundation

struct MediaPlayerController: WebPageRelated {

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

    init(page: WebPage) {
        _page = page
    }

    mutating func toggleMute() {
        isMuted = !isMuted
        page.executeJS("beam_media_toggleMute()", objectName: nil)
    }

    mutating func togglePiP() {
        isInPiP = !isInPiP
        page.executeJS("beam_media_togglePictureInPicture()", objectName: nil)
    }
}
