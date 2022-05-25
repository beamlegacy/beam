import BeamCore
import Promises

/**
 The expected API for a WebPage to work (received messages, point and shoot) with.

 Defining this protocol allows to provide a mock implementation for testing.
 */
protocol WebPage: AnyObject, Scorable {

    var webView: BeamWebView { get }
    var webviewWindow: NSWindow? { get }

    var frame: NSRect { get }

    var title: String { get }
    var url: URL? { get set }

    /// An object publishing updates about the content currently displayed.
    var contentDescription: BrowserContentDescription? { get set }

    /// The user typed text that ended up opening this page.
    var originalQuery: String? { get }
    var hasError: Bool { get set }
    var responseStatusCode: Int { get set }

    var errorPageManager: ErrorPageManager? { get set }
    var fileStorage: BeamFileStorage? { get }
    var downloadManager: DownloadManager? { get }
    var webViewNavigationHandler: WebViewNavigationHandler? { get }
    var browsingScorer: BrowsingScorer? { get }
    var webAutofillController: WebAutofillController? { get }
    var mediaPlayerController: MediaPlayerController? { get set }

    var pointAndShootInstalled: Bool { get }
    var pointAndShootEnabled: Bool { get }
    var pointAndShoot: PointAndShoot? { get }
    var webFrames: WebFrames? { get }
    var webPositions: WebPositions? { get }

    var authenticationViewModel: AuthenticationViewModel? { get set }
    var searchViewModel: SearchViewModel? { get set }
    var mouseHoveringLocation: MouseHoveringLocation { get set }
    var textSelection: String? { get set }

    @discardableResult
    func executeJS(_ jsCode: String, objectName: String?, frameInfo: WKFrameInfo?, successLogCategory: LogCategory) -> Promise<Any?>

    // MARK: Note handling
    func addContent(content: [BeamElement], with source: URL?, reason: NoteElementAddReason)
    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?)
    func getNote(fromTitle: String) -> BeamNote?

    // MARK: Tab handling
    func createNewTab(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, rect: NSRect) -> WebPage?
    func createNewWindow(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView
    func tabWillClose()

    func collectTab()
    /**
     - Returns: if the webpage is displayed in the active browser tab.
     */
    func isActiveTab() -> Bool

    // MARK: Navigation handling
    func shouldNavigateInANewTab(url: URL) -> Bool
    func addTextToClusteringManager(_ text: String, url: URL)

    // MARK: Mouse Interactions
    func allowsMouseMoved(with event: NSEvent) -> Bool
}

protocol WebPageRelated {
    /// Should be implemented as a `weak` value to avoid memory leaks
    var page: WebPage? { get set }
}

enum JavascriptExecutionError: Error {
    case webPageDeallocated
}

// MARK: - Default WebPage methods implementations
extension WebPage {

    @discardableResult
    func executeJS(_ jsCode: String, objectName: String?, frameInfo: WKFrameInfo? = nil, successLogCategory: LogCategory = .javascript) -> Promise<Any?> {
        Promise<Any?> { [weak self] fulfill, reject in
            var command = jsCode

            guard let self = self else {
                let error = JavascriptExecutionError.webPageDeallocated
                Logger.shared.logError("(\(command) failed: \(String(describing: error))", category: .javascript)
                reject(error)
                return
            }

            if let configuration = self.webView.configurationWithoutMakingCopy as? BeamWebViewConfiguration {
                if let name = objectName {
                    command = configuration.obfuscate(str: "beam.__ID__\(name)." + jsCode)
                } else {
                    command = configuration.obfuscate(str: jsCode)
                }
            }
            self.webView.evaluateJavaScript(command, in: frameInfo, in: WKContentWorld.page) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError("(\(command) failed: \(String(describing: error))", category: .javascript)
                    reject(error)
                case .success(let response):
                    Logger.shared.logInfo("(\(command) succeeded: \(String(describing: response))", category: successLogCategory)
                    fulfill(response)
                }
            }
        }
    }

    func addContent(content: [BeamElement], with source: URL? = nil, reason: NoteElementAddReason) { }
    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?) { }
    /// Calls BeamNote to fetch a note from the documentManager
    /// - Parameter noteTitle: The title of the Note
    /// - Returns: The fetched note or nil if no note exists
    func getNote(fromTitle: String) -> BeamNote? {
        nil
    }

    func tabWillClose() {
        self.authenticationViewModel?.cancel()
    }

    func collectTab() {}

    func isActiveTab() -> Bool { false }
    func createNewTab(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, setCurrent: Bool, rect: NSRect) -> WebPage? {
        self
    }

    func shouldNavigateInANewTab(url: URL) -> Bool { false }

    func createNewWindow(_ request: URLRequest, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        return webView
    }

    func addTextToClusteringManager(_ text: String, url: URL) { }
    func allowsMouseMoved(with event: NSEvent) -> Bool { true }

    func handleFormSubmit(frameInfo: WKFrameInfo) {
        webAutofillController?.handleWebFormSubmit(with: "", frameInfo: frameInfo)
    }
}

extension WebPage {

    var contentType: BrowserContentType {
        contentDescription?.type ?? .web
    }

}

extension WebPage {

    func searchInContent(fromSelection: Bool = false) {
        guard self.searchViewModel == nil else {
            self.searchViewModel?.isEditing = true
            return
        }

        switch contentType {
        case .web:
            searchViewModel = SearchViewModel(context: .web) { [weak self] search in
                self?.find(search, using: "find")
            } onLocationIndicatorTap: { [weak self] position in
                self?.executeJS("window.scrollTo(0, \(position));", objectName: nil)
            } next: { [weak self] search in
                self?.find(search, using: "findNext")
            } previous: { [weak self] search in
                self?.find(search, using: "findPrevious")
            } done: { [weak self] in
                self?.executeJS("findDone()", objectName: "SearchWebPage")
                self?.searchViewModel = nil
            }

            if fromSelection {
                self.executeJS("getSelection()", objectName: "SearchWebPage")
            }

        case .pdf:
            searchViewModel = SearchViewModel(
                context: .web,
                onLocationIndicatorTap: { _ in },
                next: { [weak self] _ in
                    self?.searchViewModel?.currentOccurence += 1
                },
                previous: { [weak self] _ in
                    self?.searchViewModel?.currentOccurence -= 1
                },
                done: { [weak self] in
                    self?.searchViewModel?.searchTerms = ""
                    self?.searchViewModel = nil
                }
            )

            if fromSelection,
               let pdfContentDescription = contentDescription as? PDFContentDescription,
               let selection = pdfContentDescription.contentState.currentSelection {
                searchViewModel?.searchTerms = selection
            }
        }
    }

    func cancelSearch() {
        guard let searchViewModel = self.searchViewModel else { return }
        searchViewModel.close()
        NSApp.mainWindow?.makeFirstResponder(webView)
    }

    private func find(_ search: String, using function: String) {
        let escaped = search.replacingOccurrences(of: "//", with: "///").replacingOccurrences(of: "\"", with: "\\\"")
        self.executeJS("\(function)(\"\(escaped)\")", objectName: "SearchWebPage")
    }

}

extension WebPage {

    func quickSearchQueryWithSelection() {
        let state = AppDelegate.main.window?.state
        guard let query = textSelection, let tuple = state?.urlFor(query: query), let url = tuple.0 else {
            return
        }
        state?.createTab(withURLRequest: URLRequest(url: url))
    }

}
