import AppKit
import Combine
import SwiftUI

/// NSPanel subclass displaying a ``VideoCallsView``.
/// It displays an entirely custom titleBar with custom trafficLights buttons.
/// It offers also some shrink/expand capabilities you can typically call when it looses key state.
final class VideoCallsPanel: SimpleClearHostingPanel {

    private static let panelMinSize: NSSize = .init(width: 336, height: 238 + 36)
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
    private let shrinkedSize: CGSize
    private var actualContentViewFrame: CGRect {
        let padding = viewModel.isShrinked ? VideoCallsView.shadowPadding : 0
        return self.contentView?.bounds.insetBy(dx: padding, dy: padding) ?? CGRect(origin: .zero, size: self.frame.size)
    }

    init(viewModel: VideoCallsViewModel, webView: BeamWebView) {
        self.viewModel = viewModel

        let mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView, .nonactivatingPanel]
        let minSizeShadowInset = VideoCallsView.shadowPadding
        let shrinkedSize = CGSize(width: Self.panelMinSize.width + minSizeShadowInset*2, height: Self.panelMinSize.height + minSizeShadowInset*2)
        self.shrinkedSize = shrinkedSize

        let rect = CGRect(origin: .zero, size: viewModel.isShrinked ? shrinkedSize : Self.panelIdealSize)
        super.init(rect: rect, styleMask: mask)
        self.collectionBehavior = [.fullScreenPrimary]
        self.worksWhenModal = true
        self.becomesKeyOnlyIfNeeded = true
        self.isFloatingPanel = true
        self.isOpaque = false
        self.hasShadow = true
        self.backgroundColor = .clear
        self.acceptsMouseMovedEvents = true
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
        let trackingArea = NSTrackingArea(rect: frame, options: [.mouseEnteredAndExited, .activeAlways, .mouseMoved], owner: self, userInfo: nil)
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
        originShifted.x -= self.shrinkedSize.width / 2
        originShifted.y -= self.shrinkedSize.height / 2
        frameToRestore.origin = originShifted
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if actualContentViewFrame.contains(event.locationInWindow) {
            viewModel.mouseEntered()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard !viewModel.isTransitioning else { return }
        handleMouseMoved(with: event.locationInWindow)
    }

    private func handleMouseMoved(with locationInWindow: CGPoint) {
        if actualContentViewFrame.contains(locationInWindow) {
            viewModel.mouseEntered()
        } else if !actualContentViewFrame.contains(locationInWindow) {
            viewModel.mouseExited()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !actualContentViewFrame.contains(event.locationInWindow) {
            viewModel.mouseExited()
        }
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

    func windowWillEnterFullScreen(_ notification: Notification) {
        self.styleMask.insert(.resizable)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullscreen = true
        if !viewModel.isFullscreen {
            viewModel.toggleFullscreen()
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        isFullscreen = false
        if viewModel.isShrinked {
            self.styleMask.remove(.resizable)
        }
        if viewModel.isFullscreen {
            viewModel.toggleFullscreen()
        }
    }
}

extension VideoCallsPanel {
    func shrink(duration: TimeInterval, completionBlock: (() -> Void)? = nil) {
        frameToRestore = frame

        var newFrame = frame
        let newSize = self.shrinkedSize
        newFrame.size = newSize
        newFrame.origin.x += (frame.width - newSize.width) / 2
        newFrame.origin.y += (frame.height - newSize.height) / 2

        NSAnimationContext.current.timingFunction = .beamWindowCurve
        NSAnimationContext.runAnimationGroup() { context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            self.animator().setFrame(newFrame, display: true, animate: true)
            self.styleMask.remove(.resizable)
        } completionHandler: {
            self.hasShadow = false
            completionBlock?()
        }
    }

    func expand(duration: TimeInterval, completionBlock: (() -> Void)? = nil) {
        NSAnimationContext.current.timingFunction = .beamWindowCurve
        self.hasShadow = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            self.animator().setFrame(frameToRestore, display: true, animate: true)
            self.styleMask.insert(.resizable)
        } completionHandler: {
            completionBlock?()
        }
    }
}

// MARK: - Helpers

private extension CAMediaTimingFunction {
    static let beamWindowCurve: CAMediaTimingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.16, 0.3, 1.1)
}
