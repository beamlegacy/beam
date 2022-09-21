import AppKit
import BeamCore

/// A simple manager allowing to start a video calls session.
final class VideoCallsManager: NSObject {

    typealias VideoCallsAutoJoinAlertContext = (alert: NSAlert, meeting: Meeting)

    /// Error thrown when interacting with the ``VideoCallsManager``
    enum Error: LocalizedError {
        case existingSession
        case tabNotEligible
    }

    /// Current panel representing current video call session.
    private(set) weak var currentPanel: VideoCallsPanel?

    /// Indicates if an auto-join is pending.
    var willAutoJoinCall: Bool {
        return autoJoinTimer != nil
    }

    private var webViewController: WebViewController?
    private var autoJoinTimer: Timer?

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Starts a video call session within a dedicated panel.
    func start(with request: URLRequest, faviconProvider: FaviconProvider?) throws {
        guard currentPanel == nil else {
            throw Error.existingSession
        }
        let webView = BeamWebView(frame: .zero, configuration: BrowserTab.webViewConfiguration)
        webView.uiDelegate = self
        webViewController = WebViewController(with: webView)
        let panel = panel(for: webView, faviconProvider: faviconProvider)
        webView.load(request)
        display(panel: panel)
    }

    /// Checks if the tab is eligible for being in video call.
    /// - Parameter tab: the ``BrowserTab`` to check.
    /// - Returns: `true` if the tab can be detached in a video call panel, `false` otherwise.
    func isEligible(tab: BrowserTab) -> Bool {
        return currentPanel == nil && (tab.url?.isEligibleForVideoCall ?? false)
    }

    /// Detaches the tab to a side panel if eligible.
    /// - Parameter tab: the ``BrowserTab`` to detach.
    func detachTabIntoSidePanel(_ tab: BrowserTab) throws {
        guard isEligible(tab: tab) else {
            throw Error.tabNotEligible
        }
        let panel = panel(for: tab.webView, faviconProvider: tab.data?.faviconProvider)
        tab.removeFromWindow()
        display(panel: panel)
    }

    /// Attempts to switch and provide a replacement of an alert shown in a ``BeamWebView`` to auto-join a meet.
    /// - Parameters:
    ///   - message: the message shown within the original alert.
    ///   - frameInfo: the ``WKFrameInfo`` of the original alert.
    ///   - completionHandler: a completionHandler with the context (new alert and related meeting)
    ///   or `nil` if the original alert shouldn't be switched.
    func switchJavaScriptAlertIfNecessary(
        with message: String,
        frameInfo: WKFrameInfo,
        completionHandler: @escaping ((VideoCallsAutoJoinAlertContext?) -> Void)
    ) {
        guard let url = frameInfo.request.url, url.host == URL.googleCalendarHost else { completionHandler(nil); return }
        guard let window = frameInfo.webView?.window as? BeamWindow else { completionHandler(nil); return }
        window.data.calendarManager.requestMeetings(for: Date(), onlyToday: true) { [unowned self] meetings in
            guard let meeting = meetings.first(where: { message.contains($0.name) }) else { completionHandler(nil); return }
            completionHandler(self.autoJoinAlertContext(for: meeting, from: message))
        }
    }

    /// Starts an auto-join Timer for the specified meeting.
    /// - Parameters:
    ///   - meeting: the ``Meeting`` to join.
    ///   - faviconProvider: a ``FaviconProvider`` optional instance.
    func autoJoinMeeting(_ meeting: Meeting, faviconProvider: FaviconProvider?) {
        autoJoinTimer = Timer.scheduledTimer(withTimeInterval: meeting.startTime.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            defer { self?.autoJoinTimer = nil }
            do {
                let meetingLinkRequest = meeting.meetingLink.flatMap { URL(string: $0) }.map { URLRequest(url: $0) }
                if let meetingLinkRequest = meetingLinkRequest {
                    try self?.start(with: meetingLinkRequest, faviconProvider: faviconProvider)
                }
            } catch {
                UserAlert.showError(error: error)
            }
        }
    }

    /// Cancel auto-joining of a session, if any.
    func cancelAutoJoin() {
        autoJoinTimer?.invalidate()
        autoJoinTimer = nil
    }
}

private extension VideoCallsManager {
    func panel(for webView: BeamWebView, faviconProvider: FaviconProvider?) -> VideoCallsPanel {
        let viewModel = VideoCallsViewModel(client: .init(webView: webView), faviconProvider: faviconProvider)
        return VideoCallsPanel(viewModel: viewModel, webView: webView)
    }

    func display(panel: VideoCallsPanel) {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        currentPanel = panel
    }
}

private extension VideoCallsManager {
    func autoJoinAlertContext(for meeting: Meeting, from originalMessage: String) -> VideoCallsAutoJoinAlertContext {
        let alert = NSAlert()

        var title: String = meeting.name
        // Let's try to extract the calendar name from the original alert message, contained between parentheses.
        if let regex = try? NSRegularExpression(pattern: #"\((.*?)\)"#) {
            let matches = regex.matches(in: originalMessage, range: .init(location: .zero, length: originalMessage.utf16.count))
            if let match = matches.first, var calendar = originalMessage.substring(fromMatch: match) {
                calendar.removeFirst()
                calendar.removeLast()
                title += "\n\(String(calendar))"
            }
        }

        let startTimeFormatted = dateFormatter.string(from: meeting.startTime)

        alert.messageText = title
        alert.informativeText = loc(
            String(format: "Your meeting starts at %@. Beam will automatically open the call when it starts.", startTimeFormatted)
        )
        alert.addButton(withTitle: loc(String(format: "Auto Join at %@", startTimeFormatted)))
        alert.addButton(withTitle: loc("OK"))

        return (alert, meeting)
    }
}

extension VideoCallsManager.Error {
    var errorDescription: String? {
        switch self {
        case .existingSession:
            return loc("A video call session is already ongoing.")
        case .tabNotEligible:
            return loc("This tab is not eligible for the side call window.")
        }
    }
}

extension VideoCallsManager: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let urlRequest = navigationAction.request
        if let mainWindow = AppDelegate.main.window {
            mainWindow.state.createTab(withURLRequest: urlRequest)
        } else {
            let window = AppDelegate.main.createWindow(frame: nil, becomeMain: false)
            window?.state.createTab(withURLRequest: urlRequest, setCurrent: true)
        }
        return nil
    }
}

private extension String {
    func substring(fromMatch match: NSTextCheckingResult) -> Substring? {
        guard let range = Range(match.range, in: self) else { return nil }
        return self[range]
    }

    var firstDate: String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        guard let match = detector.matches(in: self, range: NSRange(location: .zero, length: utf16.count)).first else { return nil }
        return substring(fromMatch: match).map(String.init)
    }
}

private extension URL {
    var isEligibleForVideoCall: Bool {
        guard !isFileURL, let host = host else { return false }
        if host.contains(Self.googleMeetHost) {
            return true
        }
        if host.contains(Self.zoomHost) {
            return path.contains("wc") // "webclient"
        }
        return false
    }

    static var googleCalendarHost: String {
        "calendar.google.com"
    }

    static var googleMeetHost: String {
        "meet.google.com"
    }

    static var zoomHost: String {
        "zoom.us"
    }
}
