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

    private let JSObjectName = "MDPLR"
    weak var page: WebPage?
    var isPlaying: Bool {
        switch playState {
        case .playing, .paused:
            return true
        default:
            return false
        }
    }
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
            self.page?.executeJS("media_toggleMute()", objectName: JSObjectName, frameInfo: frameInfo)
        }
    }

    mutating func togglePiP() {
        isInPiP = !isInPiP
        self.page?.executeJS("media_togglePictureInPicture()", objectName: JSObjectName, frameInfo: frameInfo)
    }
}
