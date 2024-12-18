//
//  MediaPlayerController.swift
//  Beam
//
//  Created by Remi Santos on 14/06/2021.
//

import Foundation

enum MediaPlayState: String {
    case ready
    case playing
    case paused
    case ended
}

struct MediaPlayerController: WebPageRelated {

    private let JSObjectName = "MediaPlayer"
    weak var page: WebPage?
    var isPlaying: Bool { playState == .playing }
    var playState: MediaPlayState?
    var isMuted = false
    var isPiPSupported = true
    var isInPiP = false
    var frameInfo: WKFrameInfo?

    init(page: WebPage) {
        self.page = page
    }

    mutating func toggleMute() {
        setMuted(!isMuted)
    }

    mutating func setMuted(_ muted: Bool) {
        if isMuted != muted {
            isMuted = muted
            self.page?.executeJS("toggleMute()", objectName: JSObjectName, frameInfo: frameInfo)
        }
    }

    mutating func togglePiP() {
        isInPiP = !isInPiP
        self.page?.executeJS("togglePictureInPicture()", objectName: JSObjectName, frameInfo: frameInfo)
    }
}
