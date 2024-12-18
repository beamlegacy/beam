import Foundation
import PDFKit
import SwiftUI
import Combine

final class PDFDocumentViewCoordinator: NSObject {

    private var pdfDocument: PDFDocument?
    private var nsView: CustomPDFView?
    private var swiftUIView: PDFDocumentView?
    private var findString = PassthroughSubject<String?, Never>()
    private var findMatches = [PDFSelection]()

    private var findMatchIndex = 0 {
        didSet {
            guard findMatchIndex != oldValue else { return }
            swiftUIView?.findMatchIndex?.wrappedValue = findMatchIndex
        }
    }

    private var miscCancellables = Set<AnyCancellable>()
    private var pdfNotificationCancellables = Set<AnyCancellable>()
    private let notificationCenter = NotificationCenter.default

    override init() {
        super.init()

        observeFindSubjects()
    }

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

        clearFindMatches()

        observeNSView()
        observeScrollView()
        observePDFDocument()
    }

    /// Synchronizes `PDFView` state with the SwiftUI view's bindings.
    private func update() {
        updateDisplay()

        updateFindString()
        updateFindMatch()
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
            .store(in: &miscCancellables)

        notificationCenter.publisher(for: .PDFViewDisplayModeChanged, object: nsView)
            .sink { [weak self] _ in
                self?.updateDisplayModeBindingFromNSViewState()
            }
            .store(in: &miscCancellables)

        // Paginating the document with keys can update the pagination
        notificationCenter.publisher(for: .PDFViewPageChanged, object: nsView)
            .sink { [weak self] _ in
                self?.updateDestinationBindingFromNSViewState()
            }
            .store(in: &miscCancellables)

        notificationCenter.publisher(for: .PDFViewSelectionChanged, object: nsView)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .compactMap { note in
                note.object as? PDFView
            }
            .compactMap { pdfView in
                pdfView.currentSelection?.string
            }
            .removeDuplicates()
            .sink { [weak self] selection in
                self?.swiftUIView?.onSelectionChanged?(selection)
            }
            .store(in: &miscCancellables)
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
            .store(in: &miscCancellables)

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
            .store(in: &miscCancellables)
    }

    // MARK: - Search

    private func updateFindString() {
        let string = swiftUIView?.findString
        findString.send(string)
    }

    private func updateFindMatch() {
        guard
            let index = swiftUIView?.findMatchIndex?.wrappedValue,
            findMatchIndex != index
        else {
            return
        }

        findMatchIndex = index
        selectFindMatch()
    }

    private func clearFindMatches() {
        findMatches = []
        nsView?.highlightedSelections = []
        nsView?.currentSelection = nil
    }

    private func beginFindString(_ string: String) {
        pdfDocument?.beginFindString(string, withOptions: .caseInsensitive)
    }

    private func highlightFindMatches() {
        nsView?.highlightedSelections = []

        findMatches.forEach { selection in
            selection.color = NSColor.systemYellow
        }
        nsView?.highlightedSelections = findMatches
    }

    private func selectFindMatch() {
        // Keep the match index as is if there's no existing search results, which likely means we are restoring a
        // previous search.
        if !findMatches.isEmpty {
            clampFindMatchIndex()
        }

        selectFindMatch(at: findMatchIndex)
    }

    private func selectFindMatch(at index: Int) {
        guard
            !findMatches.isEmpty,
            index >= 0,
            index < findMatches.count
        else {
            return
        }

        let selection = findMatches[index]
        nsView?.setCurrentSelection(selection, animate: true)

        if let selectionPage = selection.pages.first {
            // Get the bounds of the match in the page space and extend its dimensions, so that when
            // programmatically navigating to the match, it is located at a position away from the window bounds
            // and doesn't overlap with the toolbar.
            let selectionBoundsInPageSpace = selection.bounds(for: selectionPage)
            let extendedBounds = selectionBoundsInPageSpace.insetBy(dx: -50, dy: -120)
            nsView?.go(to: extendedBounds, on: selectionPage)
        } else {
            nsView?.scrollSelectionToVisible(nil)
        }
    }

    private func clampFindMatchIndex() {
        let matchCount = findMatches.count

        if findMatchIndex >= matchCount {
            findMatchIndex = 0

        } else if findMatchIndex < 0 {
            findMatchIndex = matchCount - 1
        }
    }

    private func resetFindMatchIndex() {
        if !findMatches.isEmpty {
            findMatchIndex = 0
        }
    }

    private func observeFindSubjects() {
        findString
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] string in
                // Before starting a new search, reset the current match index only if we are not resetting an
                // existing search. Otherwise, it's likely that we are restoring a previous search, and therefore must
                // keep the match index around and select this match once search completes.
                self?.resetFindMatchIndex()

                if let string = string, !string.isEmpty {
                    self?.beginFindString(string)
                } else {
                    self?.clearFindMatches()
                    self?.swiftUIView?.onFindMatches?([])
                    self?.swiftUIView?.onSelectionChanged?(nil)
                }
            }
            .store(in: &miscCancellables)
    }

    private func observePDFDocument() {
        pdfNotificationCancellables = []

        notificationCenter.publisher(for: .PDFDocumentDidBeginFind, object: pdfDocument)
            .sink { [weak self] _ in
                self?.findMatches = []
            }
            .store(in: &pdfNotificationCancellables)

        notificationCenter.publisher(for: .PDFDocumentDidFindMatch, object: pdfDocument)
            .compactMap { note in
                note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection
            }
            .sink { [weak self] selection in
                self?.findMatches.append(selection)
            }
            .store(in: &pdfNotificationCancellables)

        notificationCenter.publisher(for: .PDFDocumentDidEndFind, object: pdfDocument)
            .sink { [weak self] _ in
                self?.highlightFindMatches()
                self?.selectFindMatch()

                if let selections = self?.findMatches {
                    self?.swiftUIView?.onFindMatches?(selections)
                }
            }
            .store(in: &pdfNotificationCancellables)
    }

}

// MARK: - PDFViewDelegate

extension PDFDocumentViewCoordinator: PDFViewDelegate {

    func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
        swiftUIView?.onClickLink?(url)
    }

}
