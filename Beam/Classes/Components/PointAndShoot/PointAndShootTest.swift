import XCTest
@testable import Beam
@testable import BeamCore
import Promises

class TestWebPage: WebPage {

    var events: [String] = []

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    private(set) var originalQuery: String?
    private(set) var pointAndShootAllowed: Bool = true
    private(set) var title: String = ""
    private(set) var url: URL?
    var score: Float = 0
    var pointAndShoot: PointAndShoot
    var browsingScorer: BrowsingScorer
    var passwordOverlayController: PasswordOverlayController
    private(set) var webviewWindow: NSWindow?
    private(set) var frame: NSRect = NSRect()

    init(browsingScorer: BrowsingScorer, passwordOverlayController: PasswordOverlayController, pns: PointAndShoot) {
        self.browsingScorer = browsingScorer
        self.passwordOverlayController = passwordOverlayController
        self.pointAndShoot = pns
    }
    var webView: BeamWebView!

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addCSS \(source.hashValue) \(String(describing: when))")
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addJS \(source.hashValue) \(String(describing: when))")
    }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        events.append("executeJS \(objectName ?? "").\(jsCode)")
        return Promise(true)
    }

    func addToNote(allowSearchResult: Bool) -> BeamCore.BeamElement? {
        events.append("addToNote \(allowSearchResult)")
        return nil
    }

    func setDestinationNote(_ note: BeamCore.BeamNote, rootElement: BeamCore.BeamElement?) {
        events.append("setDestinationNote \(note) \(String(describing: rootElement))")
    }

    func getNote(fromTitle: String) -> BeamCore.BeamNote? {
        events.append("getNote \(fromTitle)")
        return nil
    }
}

class PointAndShootUIMock: PointAndShootUI {
    var events: [String] = []

    override func drawPoint(target: PointAndShoot.Target) {
        events.append("drawPoint \(target)")
    }

    override func createGroup(noteInfo: NoteInfo, edited: Bool) -> ShootGroupUI {
        events.append("createGroup \(String(describing: noteInfo)) \(edited)")
        return super.createGroup(noteInfo: noteInfo, edited: edited)
    }
}

//enum PointAndShootStatusMock: PointAndShootStatus

class PointAndShootMock: PointAndShoot {
    override func point(target: Target) {
        super.status = PointAndShootStatus.pointing
        return super.point(target: target)
    }
    override func complete(noteInfo: NoteInfo, quoteId: UUID) throws {
        super.status = PointAndShootStatus.none
        super.shootGroups.append(super.activeShootGroup ?? PointAndShoot.ShootGroup())
        return try super.complete(noteInfo: noteInfo, quoteId: quoteId)
    }
    override func resetStatus() {
        super.status = PointAndShootStatus.none
    }
}

class PasswordStoreMock: PasswordStore {
    func entries(for host: URL, completion: @escaping ([PasswordManagerEntry]) -> Void) {}

    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {}

    func password(host: URL, username: String, completion: @escaping (String?) -> Void) {}

    func save(host: URL, username: String, password: String) {}

    func delete(host: URL, username: String) {}
}

class BrowsingScorerMock: WebPageHolder, BrowsingScorer {

    override init() {
        super.init()
    }

    private(set) var currentScore: BeamCore.Score = Score()

    func updateScore() {}

    func addTextSelection() {}
}

class PointAndShootTest: XCTestCase {

    func testBed() -> (PointAndShootMock, PointAndShootUIMock) {
        let testPasswordStore = PasswordStoreMock()
        let testPasswordOverlayController = PasswordOverlayController(passwordStore: testPasswordStore, passwordManager: .shared)
        let testBrowsingScorer = BrowsingScorerMock()
        let testUI = PointAndShootUIMock()
        let pns = PointAndShootMock(ui: testUI, scorer: testBrowsingScorer)
        let testPage = TestWebPage(browsingScorer: testBrowsingScorer, passwordOverlayController: testPasswordOverlayController, pns: pns)
        testPage.browsingScorer.page = testPage
        testPage.passwordOverlayController.page = testPage
        testPage.pointAndShoot.page = testPage
        return (pns, testUI)
    }

    func testPointAndUnpoint() throws {
        let (pns, testUI) = testBed()

        let target: PointAndShoot.Target = PointAndShoot.Target(
                area: NSRect(x: 101, y: 102, width: 301, height: 302),
                mouseLocation: NSPoint(x: 201, y: 202),
                html: "<p>Pointed text</p>"
        )
        pns.point(target: target)
        XCTAssertEqual(pns.isPointing, true)
        XCTAssertEqual(testUI.events.count, 1)
        XCTAssertEqual(testUI.events[0], "drawPoint Target(area: (101.0, 102.0, 301.0, 302.0), quoteId: nil, "
                + "mouseLocation: (201.0, 202.0), html: \"<p>Pointed text</p>\")")

        pns.unpoint()
        XCTAssertEqual(pns.isPointing, false)
        XCTAssertEqual(testUI.events.count, 1)
    }

    // swiftlint:disable:next function_body_length
    func testPointAndShootBlock() throws {
        let (pns, testUI) = testBed()

        let target1: PointAndShoot.Target = PointAndShoot.Target(
                area: NSRect(x: 101, y: 102, width: 301, height: 302),
                mouseLocation: NSPoint(x: 201, y: 202),
                html: "<p>Pointed text</p>"
        )
        // Point
        pns.point(target: target1)
        pns.draw()
        // Shoot
        pns.shoot(targets: [target1], origin: "https://rr0.org")
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(pns.status, .shooting)
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.activeShootGroup?.targets.count, 1)   // One current shoot
        XCTAssertEqual(pns.shootGroups.count, 0)         // But not validated yet

        // Cancel shoot
        pns.resetStatus()
        XCTAssertEqual(pns.status, .none)           // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.activeShootGroup == nil, true)       // No current shoot
        XCTAssertEqual(pns.shootGroups.count, 0)         // No shoot group memorized

        // Shoot again
        pns.point(target: target1) // first point
        pns.draw()
        pns.shoot(targets: [target1], origin: "https://rr0.org") // then shoot
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(pns.status, .shooting)       // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 6)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.shootGroups.count, 0)         // Not validated yet

        // Validate shoot
        try pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"), quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!)
        XCTAssertEqual(pns.status, .none)       // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 6)
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.shootGroups.count, 1)         // One shoot group memorized

        let target2: PointAndShoot.Target = PointAndShoot.Target(
                area: NSRect(x: 101, y: 102, width: 301, height: 302),
                mouseLocation: NSPoint(x: 201, y: 202),
                html: "<p>Pointed text</p>"
        )
        // Shoot twice
        pns.point(target: target2) // first point
        pns.draw()
        pns.shoot(targets: [target2], origin: "https://javarome.com")
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(testUI.groupsUI.count, 1)    // Seeing the current shoot only
        XCTAssertEqual(pns.shootGroups.count, 1)         // Second one not validated yet

        // Validate second shoot
        try pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"), quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!)
        XCTAssertEqual(testUI.events.count, 9)
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.shootGroups.count, 2)         // Two shoot groups memorized
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
