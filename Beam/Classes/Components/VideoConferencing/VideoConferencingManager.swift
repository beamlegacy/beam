import AppKit

/// A simple manager allowing to start a video conferencing session.
final class VideoConferencingManager {

    /// Error thrown when interacting with the ``VideoCallManager``
    enum Error: LocalizedError {
        case existingSession
    }

    /// Current panel holding a video conferencing session.
    private(set) weak var currentPanel: VideoConferencingPanel?

    /// Starts a video conferencing session within a dedicated panel.
    func startVideoConferencing(with request: URLRequest) throws {
        guard currentPanel == nil else {
            throw Error.existingSession
        }
        let webView = BeamWebView(frame: .zero, configuration: BrowserTab.webViewConfiguration)
        let viewModel = VideoConferencingViewModel(client: .init(webView: webView))
        let panel = VideoConferencingPanel(viewModel: viewModel, webView: webView)
        webView.load(request)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        currentPanel = panel
    }
    
}
