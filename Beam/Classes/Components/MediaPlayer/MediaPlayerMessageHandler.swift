import Foundation
import BeamCore

enum MediaPlayerMessages: String, CaseIterable {
    /**
     a media changed its playing/paused state
     */
    case media_playing_changed
}

class MediaPlayerMessageHandler: BeamMessageHandler<MediaPlayerMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: MediaPlayerMessages.self, jsFileName: "MediaPlayer")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        guard let messageKey = MediaPlayerMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for media message handler", category: .web)
            return
        }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        case MediaPlayerMessages.media_playing_changed:
            guard let msgPayload = msgPayload,
                  let playing = msgPayload["playing"] as? Bool,
                  let muted = msgPayload["muted"] as? Bool,
                  let pipSupported = msgPayload["pipSupported"] as? Bool,
                  let isInPip = msgPayload["isInPip"] as? Bool
            else { return }
            webPage.mediaPlayerController?.isPlaying = playing
            webPage.mediaPlayerController?.isMuted = muted
            webPage.mediaPlayerController?.isPiPSupported = pipSupported
            webPage.mediaPlayerController?.isInPiP = isInPip
        }
    }
}
