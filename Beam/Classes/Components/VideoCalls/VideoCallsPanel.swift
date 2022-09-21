import AppKit
import Combine
import SwiftUI

/// NSPanel subclass displaying a ``VideoCallsView``.
/// It displays an entirely custom titleBar with custom trafficLights buttons.
/// It offers also some shrink/expand capabilities you can typically call when it looses key state.
final class VideoCallsPanel: SimpleClearHostingPanel {

    private static let panelMinSize: NSSize = .init(width: 336, height: 238)
    private static let panelIdealSize: NSSize = .init(width: 672, height: 476)

    private var frameToRestore: CGRect = .zero

    let viewModel: VideoCallsViewModel

    private(set) var isFullscreen: Bool = false {
        didSet {
            isFloatingPanel = !isFullscreen
        }
    }

    private var titleCancellable: AnyCancellable?
    private var eventMonitor: Any?
    private var isExplicitlyBeingDragged: Bool = false
    private var isProbablyBeingDragged: Bool = false

    init(viewModel: VideoCallsViewModel, webView: BeamWebView) {
        self.viewModel = viewModel

        let mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView, .nonactivatingPanel]
        super.init(rect: .zero, styleMask: mask)

        self.setFrame(.init(origin: .zero, size: viewModel.isShrinked ? Self.panelMinSize : Self.panelIdealSize), display: false)

        self.collectionBehavior = [.fullScreenPrimary]
        self.worksWhenModal = true
        self.becomesKeyOnlyIfNeeded = true
        self.isFloatingPanel = true
        self.minSize = Self.panelMinSize

        let contentView = VideoCallsView(webView: webView, viewModel: viewModel)

        self.setView(content: contentView)

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        titleCancellable = viewModel
            .$title
            .assign(to: \.title, onWeak: self)

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .leftMouseDragged]) { [weak self, weak viewModel] event in
            guard let self = self, let viewModel = viewModel else { return event }
            return self.handleEvent(event, viewModel: viewModel)
        }

        self.delegate = self

        configureTrackingArea()
    }

    func configureTrackingArea() {
        let trackingArea = NSTrackingArea(rect: frame, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        contentView?.addTrackingArea(trackingArea)
    }

    deinit {
        eventMonitor.map { NSEvent.removeMonitor($0) }
    }

    private func handleEvent(_ event: NSEvent, viewModel: VideoCallsViewModel) -> NSEvent {
        guard event.window === self else { return event }
        switch event.type {
        case .leftMouseUp where isExplicitlyBeingDragged:
            isExplicitlyBeingDragged = false
        case .leftMouseUp:
            viewModel.expand()
            makeKey()
        case .leftMouseDragged where viewModel.isShrinked:
            performDrag(with: event)
            isExplicitlyBeingDragged = true
        default:
            break
        }
        return event
    }

    override func performDrag(with event: NSEvent) {
        super.performDrag(with: event)

        var originShifted = frame.origin
        originShifted.x -= Self.panelMinSize.width / 2
        originShifted.y -= Self.panelMinSize.height / 2
        frameToRestore.origin = originShifted
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        viewModel.mouseEntered()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        viewModel.mouseExited()
    }
}

extension VideoCallsPanel: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        isProbablyBeingDragged = true
    }

    func windowDidMove(_ notification: Notification) {
        if isProbablyBeingDragged {
            frameToRestore.origin = frame.origin
        }
        isProbablyBeingDragged = false
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullscreen = true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        isFullscreen = false
    }
}

extension VideoCallsPanel {
    func shrink(animateAlongBlock: (() -> Void)? = nil) {
        frameToRestore = frame

        var newFrame = frame
        newFrame.size = Self.panelMinSize
        newFrame.origin.x += Self.panelMinSize.width / 2
        newFrame.origin.y += Self.panelMinSize.height / 2

        NSAnimationContext.current.timingFunction = .beamWindowCurve
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.300
            context.allowsImplicitAnimation = true
            self.animator().setFrame(newFrame, display: true, animate: true)
            animateAlongBlock?()
        }
    }

    func expand(animateAlongBlock: (() -> Void)? = nil) {
        NSAnimationContext.current.timingFunction = .beamWindowCurve
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.300
            context.allowsImplicitAnimation = true
            self.animator().setFrame(frameToRestore, display: true, animate: true)
            animateAlongBlock?()
        }
    }
}

// MARK: - Helpers

private extension CAMediaTimingFunction {
    static let beamWindowCurve: CAMediaTimingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.16, 0.3, 1.1)
}
