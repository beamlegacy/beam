//
//  MediaPlayerController.swift
//  Beam
//
//  Created by Remi Santos on 14/06/2021.
//

import Foundation

struct MediaPlayerController: WebPageRelated {
    var page: WebPage

    var isPlaying = false
    var isMuted = false
    var isPiPSupported = true
    var isInPiP = false

    mutating func toggleMute() {
        isMuted = !isMuted
        page.executeJS("beam_media_toggleMute()", objectName: nil)
    }

    mutating func togglePiP() {
        isInPiP = !isInPiP
        page.executeJS("beam_media_togglePictureInPicture()", objectName: nil)
    }
}
