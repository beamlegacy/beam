import Foundation
import BeamCore

/// Provides a web view to be used to display embeds.
/// May reuse a web view currently playing in the editor's media player manager.
final class BeamWebViewProvider {

    private weak var editor: BeamTextEdit?
    private let elementId: UUID
    private let url: URL

    private var mediaPlayerManager: NoteMediaPlayerManager? {
        editor?.state?.noteMediaPlayerManager
    }

    init(editor: BeamTextEdit, elementId: UUID, url: URL) {
        self.editor = editor
        self.elementId = elementId
        self.url = url
    }

}

extension BeamWebViewProvider: BeamWebViewProviding {

    /// Provides a web view that may have been reused.
    /// - Parameter completion: A block executed with a web view and a boolean set to true if it was reused.
    func webView(_ completionHandler: @escaping (BeamWebView, Bool) -> Void) {
        if let note = editor?.note as? BeamNote,
           let webView = mediaPlayerManager?.playingWebViewForNote(note: note, elementId: elementId, url: url) {
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
