import XCTest
@testable import Beam
@testable import BeamCore

class WebPositionsMock: WebPositions {
}

class TestWebPage: WebPage {

    var events: [String] = []

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    private(set) var originalQuery: String?
    private(set) var pointAndShootAllowed: Bool = true
    private(set) var title: String = ""
    private(set) var url: URL?
    var score: Float = 0

    init() {
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addCSS \(source.hashValue) \(String(describing: when))")
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addJS \(source.hashValue) \(String(describing: when))")
    }

    func executeJS(objectName: String, jsCode: String) {
        events.append("executeJS \(objectName).\(jsCode)")
    }

    func addToNote(allowSearchResult: Bool) -> BeamCore.BeamElement? {
        events.append("addToNote \(allowSearchResult)")
        return nil
    }

    func setDestinationNote(_ note: BeamCore.BeamNote, rootElement: BeamCore.BeamElement?) {
        events.append("setDestinationNote \(note) \(rootElement)")
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

    override func clearPoint() {
        events.append("clearPoint")
    }

    override func createGroup(noteInfo: NoteInfo, edited: Bool) -> ShootGroupUI {
        events.append("createGroup \(String(describing: noteInfo)) \(edited)")
        return super.createGroup(noteInfo: noteInfo, edited: edited)
    }
}

class BrowsingScorerMock: BrowsingScorer {
    init() {}

    private(set) var currentScore: BeamCore.Score = Score()

    func updateScore() {}

    func addTextSelection() {}
}

class PointAndShootTest: XCTestCase {

    func testBed() -> (PointAndShoot, PointAndShootUIMock) {
        let testPage = TestWebPage()
        let testUI = PointAndShootUIMock()
        let testBrowsingScorer = BrowsingScorerMock()
        let testWebPositions = WebPositions()
        let pns = PointAndShoot(page: testPage, ui: testUI, scorer: testBrowsingScorer,
                                webPositions: testWebPositions)
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
        XCTAssertEqual(testUI.events[0], "drawPoint Target(area: (101.0, 102.0, 301.0, 302.0), "
                + "mouseLocation: (201.0, 202.0), html: \"<p>Pointed text</p>\")")

        pns.unpoint()
        XCTAssertEqual(pns.isPointing, false)
        XCTAssertEqual(testUI.events.count, 2)
        XCTAssertEqual(testUI.events[1], "clearPoint")
    }

    func testPointAndShootBlock() throws {
        let (pns, testUI) = testBed()

        let target1: PointAndShoot.Target = PointAndShoot.Target(
                area: NSRect(x: 101, y: 102, width: 301, height: 302),
                mouseLocation: NSPoint(x: 201, y: 202),
                html: "<p>Pointed text</p>"
        )
        pns.point(target: target1)
        pns.shoot(targets: [target1], origin: "https://rr0.org")

        pns.status = .none
        XCTAssertEqual(pns.status, .shooting)       // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 2)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.currentGroup?.targets.count, 1)   // One current shoot
        XCTAssertEqual(pns.groups.count, 0)         // But not validated yet

        // Cancel shoot
        pns.resetStatus()
        XCTAssertEqual(pns.status, .none)           // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.events[2], "clearPoint")
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.currentGroup == nil, true)       // No current shoot
        XCTAssertEqual(pns.groups.count, 0)         // No shoot group memorized

        // Shoot again
        pns.shoot(targets: [target1], origin: "https://rr0.org")
        XCTAssertEqual(pns.status, .shooting)       // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 4)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.groups.count, 0)         // Not validated yet

        // Validate shoot
        try pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"))
        XCTAssertEqual(pns.status, .none)       // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 5)
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.groups.count, 1)         // One shoot group memorized

        let target2: PointAndShoot.Target = PointAndShoot.Target(
                area: NSRect(x: 101, y: 102, width: 301, height: 302),
                mouseLocation: NSPoint(x: 201, y: 202),
                html: "<p>Pointed text</p>"
        )
        // Shoot twice
        pns.shoot(targets: [target2], origin: "https://javarome.com")
        XCTAssertEqual(testUI.groupsUI.count, 1)    // Seeing the current shoot only
        XCTAssertEqual(pns.groups.count, 1)         // Second one not validated yet

        // Validate second shoot
        try pns.complete(noteInfo: NoteInfo(id: nil, title: "Other note"))
        XCTAssertEqual(testUI.events.count, 7)
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.groups.count, 2)         // Two shoot groups memorized
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
