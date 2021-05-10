import BeamCore
import Promises

/**
 The expected API for a WebPage to work (received messages, point and shoot) with.

 Defining this protocol allows to provide a mock implementation for testing.
 */
protocol WebPage: Scorable {

    var window: NSWindow? { get }

    var frame: NSRect { get }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?>

    var scrollX: CGFloat { get set }

    var scrollY: CGFloat { get set }

    var originalQuery: String? { get }

    var pointAndShootAllowed: Bool { get }

    var title: String { get }

    var url: URL? { get }

    /**
 Add current page to a Note.

 - Parameter allowSearchResult:
 - Returns:
 */
    func addToNote(allowSearchResult: Bool) -> BeamElement?

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?)

    func getNote(fromTitle: String) -> BeamNote?

    var pointAndShoot: PointAndShoot? { get }
    var browsingScorer: BrowsingScorer? { get }
    var passwordOverlayController: PasswordOverlayController? { get }
}

protocol WebPageRelated {
    var page: WebPage? { get set }
}
