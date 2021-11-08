import BeamCore
import Promises

/**
 The expected API for a WebPage to work (received messages, point and shoot) with.

 Defining this protocol allows to provide a mock implementation for testing.
 */
protocol WebPage: AnyObject, Scorable {

    var webView: BeamWebView! { get }
    var webviewWindow: NSWindow? { get }

    var frame: NSRect { get }

    var originalQuery: String? { get }
    var userTypedDomain: URL? { get set }
    var title: String { get }
    var url: URL? { get }
    var hasError: Bool { get set }
    var responseStatusCode: Int { get set }

    var errorPageManager: ErrorPageManager? { get set }
    var fileStorage: BeamFileStorage? { get }
    var downloadManager: DownloadManager? { get }
    var navigationController: WebNavigationController? { get }
    var browsingScorer: BrowsingScorer? { get }
    var passwordOverlayController: PasswordOverlayController? { get }
    var mediaPlayerController: MediaPlayerController? { get set }

    var pointAndShootAllowed: Bool { get }
    var pointAndShoot: PointAndShoot? { get }
    var webPositions: WebPositions? { get }

    @discardableResult
    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?>

    // MARK: Note handling
    func addToNote(allowSearchResult: Bool, inSourceBullet: Bool) -> BeamElement?
    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?)
    func getNote(fromTitle: String) -> BeamNote?

    // MARK: Tab handling
    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage?
    func createNewWindow(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView
    func closeTab()
    /**
     - Returns: if the webpage is displayed in the active browser tab.
     */
    func isActiveTab() -> Bool

    // MARK: Navigation handling
    /// Leave the page, either by back or forward.
    func leave()
    var appendToIndexer: ((URL, Readability) -> Void)? { get }
    func shouldNavigateInANewTab(url: URL) -> Bool
    func navigatedTo(url: URL, title: String?, reason: NoteElementAddReason)
    func addTextToClusteringManager(_ text: String, url: URL)

    var authenticationViewModel: AuthenticationViewModel? { get set }
    var searchViewModel: SearchViewModel? { get set }

}

protocol WebPageRelated {
    var page: WebPage { get set }
}

class WebPageHolder: NSObject, WebPageRelated {
    private weak var _page: WebPage?

    var page: WebPage {
        get {
            guard let definedPage = _page else {
                fatalError("\(self) must have an associated WebPage")
            }
            return definedPage
        }
        set {
            _page = newValue
        }
    }

    convenience init(page: WebPage?) {
        self.init()
        _page = page
    }
}

// MARK: - Default WebPage methods implementations
extension WebPage {

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        Promise<Any?> { [unowned self] fulfill, reject in
            var command = jsCode
            if let configuration = webView.configurationWithoutMakingCopy as? BeamWebViewConfiguration {
                let parameterized = objectName != nil ? "beam.__ID__\(objectName!)." + jsCode : jsCode
                command = configuration.obfuscate(str: parameterized)
            }
            webView.evaluateJavaScript(command) { (result, error: Error?) in
                if error == nil {
                    Logger.shared.logInfo("(\(command) succeeded: \(String(describing: result))", category: .javascript)
                    fulfill(result)
                } else {
                    Logger.shared.logError("(\(command) failed: \(String(describing: error))", category: .javascript)
                    reject(error!)
                }
            }
        }
    }

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?) { }
    func addToNote(allowSearchResult: Bool, inSourceBullet: Bool) -> BeamElement? {
        nil
    }
    /// Calls BeamNote to fetch a note from the documentManager
    /// - Parameter noteTitle: The title of the Note
    /// - Returns: The fetched note or nil if no note exists
    func getNote(fromTitle: String) -> BeamNote? {
        nil
    }

    func closeTab() {
        self.authenticationViewModel?.cancel()
    }

    func isActiveTab() -> Bool { false }
    func leave() { }
    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage? {
        self
    }

    func shouldNavigateInANewTab(url: URL) -> Bool { false }
    func navigatedTo(url: URL, title: String?, reason: NoteElementAddReason) { }

    func createNewWindow(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        webView
    }

    func addTextToClusteringManager(_ text: String, url: URL) { }
}

extension WebPage {

    func searchInContent(fromSelection: Bool = false) {
        guard self.searchViewModel == nil else {
            self.searchViewModel?.isEditing = true
            return
        }

        let viewModel = SearchViewModel(context: .web) { [weak self] search in
            self?.find(search, using: "find")
        } onLocationIndicatorTap: { position in
            _ = self.executeJS("window.scrollTo(0, \(position));", objectName: nil)
        } next: { [weak self] search in
            self?.find(search, using: "findNext")
        } previous: { [weak self] search in
            self?.find(search, using: "findPrevious")
        } done: { [weak self] in
            self?.webView.page?.executeJS("findDone()", objectName: "SearchWebPage")
            self?.searchViewModel = nil
        }

        self.searchViewModel = viewModel

        if fromSelection {
            self.webView.page?.executeJS("getSelection()", objectName: "SearchWebPage")
        }
    }

    func cancelSearch() {
        guard let searchViewModel = self.searchViewModel else { return }
        searchViewModel.close()
        NSApp.mainWindow?.makeFirstResponder(webView)
    }

    func find(_ search: String, using function: String) {
        let escaped = search.replacingOccurrences(of: "//", with: "///").replacingOccurrences(of: "\"", with: "\\\"")
        self.webView.page?.executeJS("\(function)(\"\(escaped)\")", objectName: "SearchWebPage")
    }
}
