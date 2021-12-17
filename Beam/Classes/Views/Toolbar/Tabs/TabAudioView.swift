//
//  TabAudioView.swift
//  Beam
//
//  Created by Remi Santos on 09/12/2021.
//

import SwiftUI

struct TabAudioView: View {
    @ObservedObject var tab: BrowserTab
    var action: (() -> Void)?

    private var audioIsPlaying: Bool {
        tab.mediaPlayerController?.isPlaying == true
    }

    private var audioIsMuted: Bool {
        tab.mediaPlayerController?.isMuted == true
    }

    private var allowsPictureInPicture: Bool {
        tab.allowsPictureInPicture && tab.mediaPlayerController?.isPiPSupported == true
    }

    var body: some View {
        TabView.TabContentIcon(name: audioIsMuted ? "tabs-media_muted" : "tabs-media", action: action)
        .accessibility(identifier: "browserTabMediaIndicator")
        .contextMenu {
            Button("\(audioIsMuted ? "Unmute" : "Mute") this tab") {
                tab.mediaPlayerController?.toggleMute()
            }
            if allowsPictureInPicture {
                let isInPip = tab.mediaPlayerController?.isInPiP == true
                Button("\(isInPip ? "Leave" : "Enter") Picture in Picture") {
                    tab.mediaPlayerController?.togglePiP()
                }
            }
        }
    }
    }
