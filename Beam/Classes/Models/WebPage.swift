import BeamCore
import Promises

/**
 The expected API for a WebPage to work (received messages, point and shoot) with.

 Defining this protocol allows to provide a mock implementation for testing.
 */
protocol WebPage: AnyObject, Scorable {

    var downloadManager: DownloadManager { get }

    var webviewWindow: NSWindow? { get }

    var frame: NSRect { get }

    var fileStorage: BeamFileStorage { get }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?>

    var scrollX: CGFloat { get set }

    var scrollY: CGFloat { get set }

    var originalQuery: String? { get }

    var pointAndShootAllowed: Bool { get }

    var title: String { get }

    var url: URL? { get }

    var webView: BeamWebView! { get }

    /**
 Add current page to a Note.

 - Parameter allowSearchResult:
 - Returns:
 */
    func addToNote(allowSearchResult: Bool) -> BeamElement?

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?)

    func getNote(fromTitle: String) -> BeamNote?

    var pointAndShoot: PointAndShoot { get }
    var navigationController: WebNavigationController { get }
    var browsingScorer: BrowsingScorer { get }
    var passwordOverlayController: PasswordOverlayController { get }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage
    func closeTab()

    /**
     - Returns: if the webpage is displayed in the active browser tab.
     */
    func isActiveTab() -> Bool

    /*
     Leave the page, either by back or forward.
     */
    func leave()
    func navigatedTo(url: URL, read: Readability, title: String?)
}

extension WebPage {
    func addToNote(allowSearchResult: Bool) -> BeamElement? {
        nil
    }
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
}
