import AppKit
import BeamCore

/// A simple manager allowing to start a video conferencing session.
final class VideoConferencingManager {

    /// Error thrown when interacting with the ``VideoCallManager``
    enum Error: LocalizedError {
        case existingSession
        case tabNotEligible
    }

    /// Current panel representing current video conferencing session.
    private(set) weak var currentPanel: VideoConferencingPanel?

    /// Starts a video conferencing session within a dedicated panel.
    func startVideoConferencing(with request: URLRequest, faviconProvider: FaviconProvider?) throws {
        guard currentPanel == nil else {
            throw Error.existingSession
        }
        let webView = BeamWebView(frame: .zero, configuration: BrowserTab.webViewConfiguration)
        let panel = panel(for: webView)
        webView.load(request)
        display(panel: panel)
    }

    /// Detaches the tab to a side panel if eligible.
    /// - Parameter tab: the ``BrowserTab`` to detach.
    func detachTabIntoSidePanel(_ tab: BrowserTab) throws {
        guard isEligible(tab: tab) else {
            throw Error.tabNotEligible
        }
        let panel = panel(for: tab.webView)
        tab.removeFromWindow()
        display(panel: panel)
    }

    /// Checks if the tab if eligible for being in video conferencing.
    /// - Parameter tab: the ``BrowserTab`` to check.
    /// - Returns: `true` if the tab can be detached in a video conferencing panel, `false` otherwise.
    func isEligible(tab: BrowserTab) -> Bool {
        return currentPanel == nil && (tab.url?.isEligibleForVideoConferencing ?? false)
    }

    private func panel(for webView: BeamWebView) -> VideoConferencingPanel {
        let viewModel = VideoConferencingViewModel(client: .init(webView: webView))
        return VideoConferencingPanel(viewModel: viewModel, webView: webView)
    }

    private func display(panel: VideoConferencingPanel) {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        currentPanel = panel
    }
}

extension VideoConferencingManager.Error {
    var errorDescription: String? {
        switch self {
        case .existingSession:
            return loc("A video conferencing session is already ongoing.")
        case .tabNotEligible:
            return loc("This tab is not eligible for the side call window.")
        }
    }
}

private extension URL {
    var isEligibleForVideoConferencing: Bool {
        guard !isFileURL, let host = host else { return false }
        switch host {
        case Self.googleMeetHost:
            return true
        case Self.zoomHost:
            return path.contains("wc") // "webclient"
        default:
            return false
        }
    }

    static var googleMeetHost: String {
        "meet.google.com"
    }

    static var zoomHost: String {
        "zoom.us"
    }
}
