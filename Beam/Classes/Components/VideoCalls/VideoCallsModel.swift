import AppKit
import BeamCore
import Combine

/// Provides user-facing details about the session to display within the panel.
protocol VideoCallsClientProtocol {
    var webView: BeamWebView { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var urlPublisher: AnyPublisher<URL, Never> { get }
    var estimatedProgressPublisher: AnyPublisher<Double, Never> { get }
    var titlePublisher: AnyPublisher<String, Never> { get }
    @available(macOS 12.0, *) var microEnabledPublisher: AnyPublisher<Bool, Never> { get }
    @available(macOS 12.0, *) var cameraEnabledPublisher: AnyPublisher<Bool, Never> { get }
}

struct VideoCallsClient {
    let webView: BeamWebView
}

extension VideoCallsClient: VideoCallsClientProtocol {
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        return webView
            .publisher(for: \.isLoading)
            .eraseToAnyPublisher()
    }

    var urlPublisher: AnyPublisher<URL, Never> {
        return webView
            .publisher(for: \.url)
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var estimatedProgressPublisher: AnyPublisher<Double, Never> {
        return webView
            .publisher(for: \.estimatedProgress)
            .eraseToAnyPublisher()
    }

    var titlePublisher: AnyPublisher<String, Never> {
        return webView
            .publisher(for: \.title)
            .map { $0 ?? loc("Meeting") }
            .eraseToAnyPublisher()
    }

    @available(macOS 12.0, *)
    var microEnabledPublisher: AnyPublisher<Bool, Never> {
        return webView
            .publisher(for: \.microphoneCaptureState)
            .map { $0 == .active }
            .eraseToAnyPublisher()
    }

    @available(macOS 12.0, *)
    var cameraEnabledPublisher: AnyPublisher<Bool, Never> {
        return webView
            .publisher(for: \.cameraCaptureState)
            .map { $0 == .active }
            .eraseToAnyPublisher()
    }
}

/// Video calls view model meant to use with SwiftUI.
final class VideoCallsViewModel: NSObject, ObservableObject {
    /// Error thrown interacting with actions of the view model.
    enum Error: LocalizedError {
        case unableToAttach
    }

    private struct State: OptionSet {
        let rawValue: Int

        static let shrinked     = State(rawValue: 1 << 0)
        static let hovered      = State(rawValue: 1 << 1)
        static let fullscreen   = State(rawValue: 1 << 2)
    }

    /// Title shown in the panel tool but also synced to the title property of the panel/window.
    @Published private(set) var title: String = loc("Meeting")

    var isShrinked: Bool {
        return states.contains(.shrinked)
    }

    var isExpanded: Bool {
        return !isShrinked
    }

    var isHovered: Bool {
        return states.contains(.hovered)
    }

    var displayToolbar: Bool {
        return isExpanded || isHovered
    }

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var estimatedProgress: Double = .zero
    @Published private(set) var faviconImage: NSImage?

    @Published private(set) var microEnabled: Bool = false
    @Published private(set) var cameraEnabled: Bool = false
    @Published private(set) var isPageMuted: Bool = false

    private let detailsClient: VideoCallsClient
    private let faviconProvider: FaviconProvider?

    // those initial states have to match the @Published properties
    private var states: State = [] {
        willSet {
            objectWillChange.send()
        }
        didSet {
            detailsClient.webView.userInteractionEnabled = !isShrinked
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    private var timerDispatchWorkItem: DispatchWorkItem?

    init(client: VideoCallsClient, faviconProvider: FaviconProvider? = nil) {
        self.detailsClient = client
        self.faviconProvider = faviconProvider

        super.init()

        detailsClient
            .webView
            .publisher(for: \.window, options: [.prior])
            .compactMap { $0 }
            .sink { [weak weakWebView = detailsClient.webView] window in
                if window is VideoCallsPanel {
                    weakWebView?.setTopContentInset(.zero)
                }
            }
            .store(in: &cancellables)

        detailsClient
            .isLoadingPublisher
            .assign(to: \.isLoading, onWeak: self)
            .store(in: &cancellables)
        detailsClient
            .estimatedProgressPublisher
            .assign(to: \.estimatedProgress, onWeak: self)
            .store(in: &cancellables)
        detailsClient
            .titlePublisher
            .assign(to: \.title, onWeak: self)
            .store(in: &cancellables)

        if #available(macOS 12.0, *) {
            detailsClient
                .microEnabledPublisher
                .assign(to: \.microEnabled, onWeak: self)
                .store(in: &cancellables)
            detailsClient
                .cameraEnabledPublisher
                .assign(to: \.cameraEnabled, onWeak: self)
                .store(in: &cancellables)
        }

        if let faviconProvider = faviconProvider {
            weak var weakWebView = detailsClient.webView
            detailsClient
                .urlPublisher
                .flatMap { url in
                    Future<Favicon?, Never> { promise in
                        faviconProvider.favicon(fromURL: url, webView: weakWebView) { favicon in
                            promise(.success(favicon))
                        }
                    }
                }
                .compactMap { $0?.image }
                .receive(on: DispatchQueue.main)
                .assign(to: \.faviconImage, onWeak: self)
                .store(in: &cancellables)
        }

        NotificationCenter.default
            .publisher(for: NSWindow.didResignKeyNotification)
            .filter { [weak self] notification in
                return (notification.object as? VideoCallsPanel) === self?.detailsClient.webView.window
            }
            .sink { [weak self] _ in
                self?.shrink()
            }
            .store(in: &cancellables)
    }

    func close() {
        detailsClient.webView.window?.close()
    }

    func attach() throws {
        guard let urlRequest = detailsClient.webView.url.map({ URLRequest(url: $0)}) else {
            throw Error.unableToAttach
        }
        close()
        detailsClient.webView.userInteractionEnabled = true
        detailsClient.webView.pageZoom = 1.0
        if AppDelegate.main.windows.isEmpty {
            let window = AppDelegate.main.createWindow(frame: nil, becomeMain: false)
            window?.state.createTab(withURLRequest: urlRequest, setCurrent: true, loadRequest: false, webView: detailsClient.webView)
            window?.makeKeyAndOrderFront(nil)
        } else {
            let mainWindow = AppDelegate.main.window ?? AppDelegate.main.windows[0]
            mainWindow.state.createTab(withURLRequest: urlRequest, setCurrent: true, loadRequest: false, webView: detailsClient.webView)
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    func toggleFullscreen() {
        detailsClient.webView.pageZoom = 1.0
        detailsClient.webView.window?.toggleFullScreen(nil)
    }

    @available(macOS 12.0, *)
    func toggleMic() async {
        await detailsClient.webView.setMicrophoneCaptureState(microEnabled ? .muted : .active)
    }

    @available(macOS 12.0, *)
    func toggleCamera() async {
        await detailsClient.webView.setCameraCaptureState(cameraEnabled ? .muted : .active)
    }

    func toggleMuteAudio() {
        detailsClient.webView._setPageMuted(isPageMuted ? [] : [.audioMuted])
        isPageMuted.toggle()
    }

    func shrink() {
        guard isExpanded, let panel = detailsClient.webView.window as? VideoCallsPanel, panel.sheets.isEmpty, !panel.isFullscreen
        else { return }
        panel.shrink {
            self.detailsClient.webView.pageZoom = 0.5
        }
        states.insert(.shrinked)
    }

    func expand() {
        guard isShrinked, let panel = detailsClient.webView.window as? VideoCallsPanel else {
            return
        }
        panel.expand {
            self.detailsClient.webView.pageZoom = 1.0
        }
        detailsClient.webView.userInteractionEnabled = true
        states.remove(.shrinked)
    }

    func mouseEntered() {
        timerDispatchWorkItem?.cancel()
        states.insert(.hovered)
    }

    func mouseExited() {
        timerDispatchWorkItem = DispatchWorkItem { [weak self] in
            self?.states.remove(.hovered)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400), execute: timerDispatchWorkItem!)
    }
}

// MARK: - Conformances

extension VideoCallsViewModel.Error {
    var errorDescription: String? {
        switch self {
        case .unableToAttach:
            return loc("An error occured while trying to attach the panel to the main window.")
        }
    }
}
