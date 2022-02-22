import Foundation
import BeamCore

/// Provides a web view to be used to display embeds.
/// May reuse a web view currently playing in the media player manager.
final class BeamWebViewProvider {

    private let note: BeamNote
    private let elementId: UUID
    private let url: URL
    private weak var mediaPlayerManager: NoteMediaPlayerManager?

    init(note: BeamNote, elementId: UUID, url: URL, noteMediaPlayerManager: NoteMediaPlayerManager) {
        self.note = note
        self.elementId = elementId
        self.url = url
        self.mediaPlayerManager = noteMediaPlayerManager
    }

}

extension BeamWebViewProvider: BeamWebViewProviding {

    /// Provides a web view that may have been reused.
    /// - Parameter completion: A block executed with a web view and a boolean set to true if it was reused.
    func webView(_ completionHandler: @escaping (BeamWebView, Bool) -> Void) {
        if let webView = mediaPlayerManager?.playingWebViewForNote(note: note, elementId: elementId, url: url) {
            completionHandler(webView, true)
            return
        }

        let configuration = BeamWebViewConfigurationBase(handlers: [
            LoggingMessageHandler(),
            MediaPlayerMessageHandler(),
            EmbedNodeMessageHandler()
        ])
        let webView = BeamWebView(frame: .zero, configuration: configuration)
        webView.setupForEmbed()
        AppDelegate.main.data.setup(webView: webView)

        completionHandler(webView, false)
    }

}
