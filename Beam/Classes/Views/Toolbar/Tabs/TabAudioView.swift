//
//  TabAudioView.swift
//  Beam
//
//  Created by Remi Santos on 09/12/2021.
//

import SwiftUI

struct TabAudioView: View {
    @ObservedObject var tab: BrowserTab
    @State var lottieName = "tabs-media_mute"
    @State var lottiePlaying = false

    var action: (() -> Void)?

    private var audioIsMuted: Bool {
        tab.mediaPlayerController?.isMuted == true
    }

    private var allowsPictureInPicture: Bool {
        tab.allowsPictureInPicture && tab.mediaPlayerController?.isPiPSupported == true
    }

    var body: some View {
        TabView.TabContentLottieIcon(name: lottieName,
                                     playing: lottiePlaying,
                                     action: action,
                                     onAnimationCompleted: {
            updateLottie(muted: audioIsMuted, playing: false)
        })
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
        .onChange(of: audioIsMuted) { [audioIsMuted] _ in
            if !lottiePlaying {
                updateLottie(muted: audioIsMuted, playing: true)
            }
        }
        .onAppear {
            updateLottie(muted: audioIsMuted, playing: false)
        }
    }

    private func updateLottie(muted: Bool, playing: Bool) {
        lottieName = muted ? "tabs-media_unmute" : "tabs-media_mute"
        lottiePlaying = playing
    }
}
