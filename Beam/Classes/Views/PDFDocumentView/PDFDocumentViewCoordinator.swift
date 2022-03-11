import Foundation
import PDFKit
import SwiftUI
import Combine

final class PDFDocumentViewCoordinator: NSObject {

    private var pdfDocument: PDFDocument?
    private var nsView: CustomPDFView?
    private var swiftUIView: PDFDocumentView?
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = NotificationCenter.default

    func setNSView(_ nsView: CustomPDFView) {
        self.nsView = nsView
        nsView.delegate = self
    }

    func setSwiftUIView(_ swiftUIView: PDFDocumentView) {
        let documentHasChanged = (pdfDocument != swiftUIView.pdfDocument)

        self.swiftUIView = swiftUIView

        if documentHasChanged {
            // PDF document has changed, update references to PDF document and SwiftUI view
            pdfDocument = swiftUIView.pdfDocument
            nsView?.document = pdfDocument

            prepare()
        } else {
            update()
        }
    }

    private func prepare() {
        if let swiftUIView = swiftUIView {
            nsView?.minScaleFactor = swiftUIView.minScaleFactor
            nsView?.maxScaleFactor = swiftUIView.maxScaleFactor
        }

        updateDisplay()

        // Move to an explicit position in the document if defined in the SwiftUI view properties, or if none provided,
        // explicitly move it to the topmost position, because of some funky `PDFView` bug where autoscaled PDFs are
        // positioned at their bottom on first display.
        // Also this workaround is sometimes effective only in the next loop, therefore we apply it twice.
        // See https://stackoverflow.com/a/27308704/952846
        updateNSViewPosition()
        DispatchQueue.main.async { [weak self] in
            self?.updateNSViewPosition()
        }

        observeNSView()
        observeScrollView()
    }

    /// Synchronizes `PDFView` state with the SwiftUI view's bindings.
    private func update() {
        updateDisplay()
    }

    private func updateDisplay() {
        guard
            let swiftUIView = swiftUIView,
            let autoScales = swiftUIView.autoScales?.wrappedValue,
            let scaleFactor = swiftUIView.scaleFactor?.wrappedValue
        else {
            return
        }

        // Update `autoScales` and `scaleFactor` values only if they have actually changed.
        // Otherwise, unnecessary executions of `PDFViewDelegate.pdfViewWillChangeScaleFactor` will happen.
        if nsView?.autoScales != autoScales {
            nsView?.autoScales = autoScales
        }

        if !autoScales,
            nsView?.scaleFactor != scaleFactor {
            nsView?.scaleFactor = scaleFactor
        }

        if let displayMode = swiftUIView.displayMode?.wrappedValue {
            nsView?.displayMode = displayMode
        }
    }

    private func updateNSViewPosition() {
        guard let destination = swiftUIView?.destination?.wrappedValue else { return }

        switch destination {
        case .top:
            goToTop()

        case let .custom(pdfDestination):
            nsView?.go(to: pdfDestination)
        }
    }

    private func updateScaleBindingsFromNSViewState() {
        guard let nsView = nsView else { return }

        swiftUIView?.scaleFactor?.wrappedValue = nsView.scaleFactor
        swiftUIView?.autoScales?.wrappedValue = nsView.autoScales
    }

    private func updateDisplayModeBindingFromNSViewState() {
        guard let nsView = nsView else { return }

        swiftUIView?.displayMode?.wrappedValue = nsView.displayMode
    }

    private func updateDestinationBindingFromNSViewState() {
        guard let currentDestination = nsView?.currentDestination else { return }

        swiftUIView?.destination?.wrappedValue = .custom(currentDestination)
    }

    private func goToTop() {
        guard let pdfView = nsView,
              let firstPage = pdfDocument?.page(at: 0)
        else {
            return
        }

        let firstPageBounds = firstPage.bounds(for: pdfView.displayBox)
        let rect = CGRect(x: 0, y: firstPageBounds.height, width: 0, height: 0)

        pdfView.go(to: rect, on: firstPage)
    }

    private func observeNSView() {
        guard let nsView = nsView else { return }

        notificationCenter.publisher(for: .PDFViewScaleChanged, object: nsView)
            .sink { [weak self] _ in
                self?.updateScaleBindingsFromNSViewState()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .PDFViewDisplayModeChanged, object: nsView)
            .sink { [weak self] _ in
                self?.updateDisplayModeBindingFromNSViewState()
            }
            .store(in: &cancellables)

        // Paginating the document with keys can update the pagination
        notificationCenter.publisher(for: .PDFViewPageChanged, object: nsView)
            .sink { [weak self] _ in
                self?.updateDestinationBindingFromNSViewState()
            }
            .store(in: &cancellables)
    }

    private func observeScrollView() {
        guard let scrollContentView = nsView?.scrollView?.contentView else { return }

        scrollContentView.postsBoundsChangedNotifications = true

        // Update destination only when scrolling settles.
        notificationCenter.publisher(for: NSView.boundsDidChangeNotification, object: scrollContentView)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateDestinationBindingFromNSViewState()
            }
            .store(in: &cancellables)

        // In order to get up-to-date scale values during pinch gestures, assume such gestures trigger bounds changes
        notificationCenter.publisher(for: NSView.boundsDidChangeNotification, object: scrollContentView)
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .dropFirst() // Ignore post-initialization value to prevent overriding the restored scale state
            .filter { [weak self] _ in
                self?.swiftUIView?.scaleFactor?.wrappedValue != self?.nsView?.scaleFactor
            }
            .sink { [weak self] _ in
                self?.updateScaleBindingsFromNSViewState()
            }
            .store(in: &cancellables)
    }

}

// MARK: - PDFViewDelegate

extension PDFDocumentViewCoordinator: PDFViewDelegate {

    func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        swiftUIView?.onClickLink?(url)
    }

}
