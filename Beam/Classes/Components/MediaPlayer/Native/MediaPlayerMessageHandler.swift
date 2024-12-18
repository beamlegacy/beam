import Foundation
import BeamCore

enum MediaPlayerMessages: String, CaseIterable {
    /**
     a media changed its playing/paused state
     */
    case MediaPlayer_media_playing_changed
}

class MediaPlayerMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = MediaPlayerMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "MediaPlayer_prod")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = MediaPlayerMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for media message handler", category: .web)
            return
        }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        case MediaPlayerMessages.MediaPlayer_media_playing_changed:
            guard var controller = webPage.mediaPlayerController,
                  let msgPayload = msgPayload,
                  let playStateString = msgPayload["playState"] as? String,
                  let playState = MediaPlayState(rawValue: playStateString),
                  let muted = msgPayload["muted"] as? Bool,
                  let pipSupported = msgPayload["pipSupported"] as? Bool,
                  let isInPip = msgPayload["isInPip"] as? Bool
            else { return }
            controller.playState = playState
            controller.isMuted = muted
            controller.isPiPSupported = pipSupported
            controller.isInPiP = isInPip
            controller.frameInfo = frameInfo
            webPage.mediaPlayerController = controller
        }
    }
}
