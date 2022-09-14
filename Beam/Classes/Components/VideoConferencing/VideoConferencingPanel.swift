import AppKit
import Combine
import SwiftUI

/// NSPanel subclass displaying a ``VideoConferencingView``.
/// It displays an entirely custom titleBar with custom trafficLights buttons.
/// It offers also some shrink/expand capabilities you can typically call when it looses key state.
final class VideoConferencingPanel: SimpleClearHostingPanel {

    private static let panelMinSize: NSSize = .init(width: 336, height: 238)
    private static let panelIdealSize: NSSize = .init(width: 672, height: 476)

    private var frameToRestore: CGRect = .zero

    let viewModel: VideoConferencingViewModel

    private var titleCancellable: AnyCancellable?
    private var eventMonitor: Any?
    private var isExplicitlyBeingDragged: Bool = false
    private var isProbablyBeingDragged: Bool = false

    init(viewModel: VideoConferencingViewModel, webView: BeamWebView) {
        self.viewModel = viewModel

        let mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView]
        super.init(rect: .zero, styleMask: mask)

        self.setFrame(.init(origin: .zero, size: viewModel.isExpanded ? Self.panelIdealSize : Self.panelMinSize), display: false)

        self.collectionBehavior = [.fullScreenPrimary]
        self.worksWhenModal = true
        self.becomesKeyOnlyIfNeeded = true
        self.isFloatingPanel = true
        self.minSize = Self.panelMinSize

        let contentView = VideoConferencingView(webView: webView, viewModel: viewModel)

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
    }

    deinit {
        eventMonitor.map { NSEvent.removeMonitor($0) }
    }

    private func handleEvent(_ event: NSEvent, viewModel: VideoConferencingViewModel) -> NSEvent {
        guard event.window === self else { return event }
        switch event.type {
        case .leftMouseUp where isExplicitlyBeingDragged:
            isExplicitlyBeingDragged = false
        case .leftMouseUp:
            viewModel.expand()
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

        frameToRestore.origin = frame.origin
    }
}

extension VideoConferencingPanel: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        isProbablyBeingDragged = true
    }

    func windowDidMove(_ notification: Notification) {
        if isProbablyBeingDragged {
            frameToRestore.origin = frame.origin
        }
        isProbablyBeingDragged = false
    }
}

extension VideoConferencingPanel {
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
