import PDFKit

final class CustomPDFView: PDFView {

    var onEscapeKeyDown: (() -> Void)?

    /// Recreates a new menu from scratch.
    /// We could have instead intercept the default menu in `PDFView.willOpenMenu(_:with:)`, but unfortunately it is
    /// only called when clicking outside the bounds of the PDF document.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        var items = [NSMenuItem]()
        items.append(contentsOf: sizingItems())
        items.append(.separator())
        items.append(contentsOf: pagingDisplayItems())
        items.append(.separator())
        items.append(contentsOf: pageNavigationtems())
        menu.items = items
        return menu
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.escape.rawValue {
            onEscapeKeyDown?()
        }
        super.keyDown(with: event)
    }

    private func sizingItems() -> [NSMenuItem] {
        [
            makeMenuItem(
                title: NSLocalizedString("Automatically Resize", comment: "Automatically Resize menu item"),
                identifier: Self.automaticallyResizeIdentifier,
                action: #selector(automaticallyResizeClicked)
            ),
            makeMenuItem(
                title: NSLocalizedString("Zoom In", comment: "Zoom In menu item"),
                identifier: Self.zoomInIdentifier,
                action: #selector(zoomIn(_:))
            ),
            makeMenuItem(
                title: NSLocalizedString("Zoom Out", comment: "Zoom Out menu item"),
                identifier: Self.zoomOutIdentifier,
                action: #selector(zoomOut(_:))
            ),
            makeMenuItem(
                title: NSLocalizedString("Actual Size", comment: "Actual Size menu item"),
                identifier: Self.actualSizeIdentifier,
                action: #selector(actualSizeClicked)
            )
        ]
    }

    private func pagingDisplayItems() -> [NSMenuItem] {
        [
            makeMenuItem(
                title: NSLocalizedString("Single Page", comment: "Single Page menu item"),
                identifier: Self.singlePageItemIdentifier,
                action: #selector(singlePageClicked)
            ),
            makeMenuItem(
                title: NSLocalizedString("Single Page Continuous", comment: "Single Page Continuous menu item"),
                identifier: Self.singlePageContinuousItemIdentifier,
                action: #selector(singlePageContinuousClicked)
            ),
            makeMenuItem(
                title: NSLocalizedString("Two Pages", comment: "Two Pages menu item"),
                identifier: Self.twoPagesItemIdentifier,
                action: #selector(twoPagesClicked)
            ),
            makeMenuItem(
                title: NSLocalizedString("Two Pages Continuous", comment: "Two Pages Continuous menu item"),
                identifier: Self.twoPagesContinuousItemIdentifier,
                action: #selector(twoPagesContinuousClicked)
            )
        ]
    }

    private func pageNavigationtems() -> [NSMenuItem] {
        [
            makeMenuItem(
                title: NSLocalizedString("Next Page", comment: "Next Page menu item"),
                identifier: Self.nextPageItemIdentifier,
                action: #selector(nextPageClicked)
            ),
            makeMenuItem(
                title: NSLocalizedString("Previous Page", comment: "Previous Page menu item"),
                identifier: Self.previousPageItemIdentifier,
                action: #selector(previousPageClicked)
            )
        ]
    }

    @objc private func automaticallyResizeClicked() {
        autoScales = true
    }

    @objc private func actualSizeClicked() {
        scaleFactor = 1
    }

    @objc private func singlePageClicked() {
        displayMode = .singlePage
    }

    @objc private func singlePageContinuousClicked() {
        displayMode = .singlePageContinuous
    }

    @objc private func twoPagesClicked() {
        displayMode = .twoUp
    }

    @objc private func twoPagesContinuousClicked() {
        displayMode = .twoUpContinuous
    }

    @objc private func nextPageClicked() {
        goToNextPage(nil)
    }

    @objc private func previousPageClicked() {
        goToPreviousPage(nil)
    }

    private func makeMenuItem(title: String, identifier: NSUserInterfaceItemIdentifier, action: Selector?) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.identifier = identifier
        return menuItem
    }

    // MARK: - Identifiers

    static let automaticallyResizeIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierAutomaticallyResizeItem")
    static let zoomInIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierZoomInIdentifier")
    static let zoomOutIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierZoomOutIdentifier")
    static let actualSizeIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierActualSizeIdentifier")

    static let singlePageItemIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierSinglePageItemIdentifier")
    static let singlePageContinuousItemIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierSinglePageContinuousItemIdentifier")
    static let twoPagesItemIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierTwoPagesItemIdentifier")
    static let twoPagesContinuousItemIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierTwoPagesContinuousItemIdentifier")

    static let nextPageItemIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierNextPageItemIdentifier")
    static let previousPageItemIdentifier = NSUserInterfaceItemIdentifier("CustomPDFViewMenuItemIdentifierPreviousPageItemIdentifier")

}

extension CustomPDFView {

    var scrollView: NSScrollView? {
        subviews.first(where: { $0 is NSScrollView }) as? NSScrollView
    }

}

// MARK: - NSMenuItemValidation

extension CustomPDFView: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.identifier {
        case Self.automaticallyResizeIdentifier:
            menuItem.isOn = autoScales

        case Self.actualSizeIdentifier:
            menuItem.isOn = (scaleFactor == 1)

        case Self.nextPageItemIdentifier:
            return canGoToNextPage

        case Self.previousPageItemIdentifier:
            return canGoToPreviousPage

        case Self.singlePageItemIdentifier:
            menuItem.isOn = (displayMode == .singlePage)

        case Self.singlePageContinuousItemIdentifier:
            menuItem.isOn = (displayMode == .singlePageContinuous)

        case Self.twoPagesItemIdentifier:
            menuItem.isOn = (displayMode == .twoUp)

        case Self.twoPagesContinuousItemIdentifier:
            menuItem.isOn = (displayMode == .twoUpContinuous)

        default: break
        }

        return true
    }

}

// MARK: - NSMenuItem

extension NSMenuItem {

    var isOn: Bool {
        get {
            state == .on
        }
        set {
            state = newValue ? .on : .off
        }
    }

}
