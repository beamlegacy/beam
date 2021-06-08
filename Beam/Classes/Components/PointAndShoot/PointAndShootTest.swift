import XCTest
@testable import Beam
@testable import BeamCore
import Promises
import Nimble

class TestWebPage: WebPage {

    var events: [String] = []

    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    private(set) var originalQuery: String?
    private(set) var pointAndShootAllowed: Bool = true
    private(set) var title: String = ""
    static let urlStr = "https://webpage.com"
    private(set) var url: URL? = URL(string: urlStr)
    var score: Float = 0
    var pointAndShoot: PointAndShoot
    var browsingScorer: BrowsingScorer
    var storage: BeamFileStorage
    var passwordOverlayController: PasswordOverlayController
    private(set) var webviewWindow: NSWindow?
    private(set) var frame: NSRect = NSRect()
    private(set) var downloadManager: DownloadManager
    var webView: BeamWebView!

    init(browsingScorer: BrowsingScorer, passwordOverlayController: PasswordOverlayController, pns: PointAndShoot,
         fileStorage: BeamFileStorage, downloadManager: DownloadManager) {
        self.browsingScorer = browsingScorer
        self.passwordOverlayController = passwordOverlayController
        pointAndShoot = pns
        storage = fileStorage
        self.downloadManager = downloadManager
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addCSS \(source.hashValue) \(String(describing: when))")
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addJS \(source.hashValue) \(String(describing: when))")
    }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        if objectName == "PointAndShoot" {
            switch jsCode {
            case "setStatus('pointing')":
                pointAndShoot.status = PointAndShootStatus.pointing
            case "setStatus('shooting')":
                pointAndShoot.status = PointAndShootStatus.shooting
            case "setStatus('none')":
                pointAndShoot.status = PointAndShootStatus.none
            case let assignString where jsCode.contains("assignNote"):
                Logger.shared.logDebug("\(assignString) called", category: .pointAndShoot)
                pointAndShoot.status = PointAndShootStatus.none
            default:
                Logger.shared.logDebug("no matching jsCode case, no js call mocked", category: .pointAndShoot)
            }
        }
        events.append("executeJS \(objectName ?? "").\(jsCode)")
        return Promise(true)
    }

    var activeNote: String = "Card A"
    var testNotes: [String: BeamCore.BeamNote] = ["Card A": BeamNote(title: "Card A")]

    func addToNote(allowSearchResult: Bool) -> BeamCore.BeamElement? {
        events.append("addToNote \(allowSearchResult)")
        // use last note
        return testNotes[activeNote]
    }

    func setDestinationNote(_ note: BeamCore.BeamNote, rootElement: BeamCore.BeamElement?) {
        events.append("setDestinationNote \(note) \(String(describing: rootElement))")
    }

    func getNote(fromTitle: String) -> BeamCore.BeamNote? {
        events.append("getNote \(fromTitle)")
        return testNotes[fromTitle]
    }

    var fileStorage: BeamFileStorage {
        storage
    }
}

class PointAndShootUIMock: PointAndShootUI {
    var events: [String] = []

    override func drawPoint(target: PointAndShoot.Target) {
        events.append("drawPoint \(target)")
    }

    override func createGroup(noteInfo: NoteInfo, selectionUIs: [SelectionUI], edited: Bool) -> ShootGroupUI {
        events.append("createGroup \(String(describing: noteInfo)) \(edited)")
        return super.createGroup(noteInfo: noteInfo, selectionUIs: selectionUIs, edited: edited)
    }
}

class PasswordStoreMock: PasswordStore {
    func entries(for host: URL, completion: @escaping ([PasswordManagerEntry]) -> Void) {}

    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {}

    func fetchAll(completion: @escaping ([PasswordManagerEntry]) -> Void) {}

    func password(host: URL, username: String, completion: @escaping (String?) -> Void) {}

    func save(host: URL, username: String, password: String) {}

    func delete(host: URL, username: String) {}
}

class MockUserInformationsStore: UserInformationsStore {

    func save(userInfo: UserInformations) {}

    func get() -> UserInformations {
        return UserInformations(email: "", firstName: "", lastName: "", adresses: "")
    }

    func delete() {}
}

class BrowsingScorerMock: WebPageHolder, BrowsingScorer {

    override init() {
        super.init()
    }

    private(set) var currentScore: BeamCore.Score = Score()

    func updateScore() {}

    func addTextSelection() {}
}

class FileStorageMock: BeamFileStorage {
    var events: [String] = []

    func fetch(uid: String) throws -> BeamFileRecord? { fatalError("fetch(uid:) has not been implemented") }

    func insert(name: String, uid: String, data: Data, type: String) throws {
        events.append("inserted \(name) with id \(uid) of \(type) for \(data.count) bytes")
    }

    func remove(uid: String) throws {}

    func clear() throws {}
}

class DownloadManagerMock: DownloadManager {
    var events: [String] = []

    var fractionCompleted: Double = 0.0
    var overallProgress: Progress = Progress()
    var downloads: [Download] = []

    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void) {}

    func downloadURL(_ url: URL, headers: [String: String], completion: @escaping (DownloadManagerResult) -> Void) {
        events.append("downloaded \(url) with headers \(headers)")
        completion(DownloadManagerResult.binary(data: Data([0x01, 0x02, 0x03]), mimeType: "image/png", actualURL: URL(string: "https://webpage.com/image.png")!))
    }

    func downloadFile(at url: URL, headers: [String: String], destinationFoldedURL: URL?) {}

    func waitForDownloadURL(_ url: URL, headers: [String: String]) -> DownloadManagerResult? { fatalError("waitForDownloadURL(_:headers:) has not been implemented") }
}

class PointAndShootTest: XCTestCase {
    var testPage: TestWebPage?

    func testBed() -> (PointAndShoot, PointAndShootUIMock) {
        let testPasswordStore = PasswordStoreMock()
        let userInfoStore = MockUserInformationsStore()
        let testPasswordOverlayController = PasswordOverlayController(passwordStore: testPasswordStore, userInfoStore: userInfoStore, passwordManager: .shared)
        let testBrowsingScorer = BrowsingScorerMock()
        let testUI = PointAndShootUIMock()
        let testFileStorage = FileStorageMock()
        let testDownloadManager = DownloadManagerMock()
        let pns = PointAndShoot(ui: testUI, scorer: testBrowsingScorer)
        let page = TestWebPage(browsingScorer: testBrowsingScorer,
                               passwordOverlayController: testPasswordOverlayController, pns: pns,
                               fileStorage: testFileStorage, downloadManager: testDownloadManager)
        testPage = page
        page.browsingScorer.page = page
        page.passwordOverlayController.page = page
        page.pointAndShoot.page = page
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
        pns.shoot(targets: [target1], href: pns.page.url!.string)
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
        // Shoot
        pns.shoot(targets: [target1], href: pns.page.url!.string) // then shoot
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(pns.status, .shooting)       // Disallow unpoint while shooting
        XCTAssertEqual(testUI.events.count, 6)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.shootGroups.count, 0)         // Not validated yet

        // Validate shoot
        try pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"), quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!, group: pns.activeShootGroup!)
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
        pns.shoot(targets: [target2], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(testUI.groupsUI.count, 1)    // Seeing the current shoot only
        XCTAssertEqual(pns.shootGroups.count, 1)         // Second one not validated yet

        // Validate second shoot
        try pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"), quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!, group: pns.activeShootGroup!)
        XCTAssertEqual(testUI.events.count, 12)
        XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(pns.shootGroups.count, 2)         // Two shoot groups memorized
    }

    func testPointAndShootImage() throws {
        let (pns, testUI) = testBed()

        let imageTarget: PointAndShoot.Target = PointAndShoot.Target(
                area: NSRect(x: 101, y: 102, width: 301, height: 302),
                mouseLocation: NSPoint(x: 201, y: 202),
                html: "<img src=\"someImage.png\">"
        )
         // Point
        pns.point(target: imageTarget)
        pns.draw()
        // Shoot
        pns.shoot(targets: [imageTarget], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.activeShootGroup?.targets.count, 1)   // One current shoot

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                let page = self.testPage!
                let downloadManager = page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)
                XCTAssertEqual(downloadManager?.events[0], "downloaded someImage.png -- https://webpage.com with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                XCTAssertEqual(testUI.events.count, 3)
                XCTAssertEqual(testUI.groupsUI.count, 0)    // No more shoot UI
                XCTAssertEqual(pns.shootGroups.count, 1)         // One shoot group memorized
                done()
            }
        }
    }

    func testPointAndShootYoutubeVideo() throws {
        let (pns, testUI) = testBed()

        let imageTarget: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<video style=\"width: 427px; height: 240px; left: 0px; top: 0px;\" tabindex=\"-1\" class=\"video-stream html5-main-video\" controlslist=\"nodownload\" src=\"https://www.youtube.com/3c46b995-6a5c-44c4-ae60-c62db0d15725\"></video>"
        )
        // Point
        pns.point(target: imageTarget)
        pns.draw()
        // Shoot
        pns.shoot(targets: [imageTarget], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.activeShootGroup?.targets.count, 1)   // One current shoot

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.embed(pns.page.url!.absoluteString) )
                done()
            }
        }
    }

    func testPointAndShootMultipleParagraphs() throws {
        let (pns, testUI) = testBed()

        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.<br></p>\n          <p>However, it is worth noting the significant advancements that have been made within the existing creative tooling structures. Integrating coll</p>"
        )

        // Point
        pns.point(target: paragraphTarget)
        pns.draw()
        // Shoot
        pns.shoot(targets: [paragraphTarget], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.activeShootGroup?.targets.count, 1)   // One current shoot

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 2)
                done()
            }
        }
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 2)
    }

    func testPointAndShootFilterEmptyParagraphs() throws {
        let (pns, testUI) = testBed()

        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1<br></p>\n    \n      <p>paragraph3</p>"
        )

        // Point
        pns.point(target: paragraphTarget)
        pns.draw()
        // Shoot
        pns.shoot(targets: [paragraphTarget], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()
        XCTAssertEqual(testUI.events.count, 3)
        XCTAssertEqual(testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(pns.activeShootGroup?.targets.count, 1)   // One current shoot

        // When splitting paragraphs it should produce an array of 3 items.
        let nonFilteredParagarphs = paragraphTarget.html.split(separator: "\n")
        XCTAssertEqual(nonFilteredParagarphs, ["<p>paragraph1<br></p>", "    ", "      <p>paragraph3</p>"])

        // Add shoot to note
        waitUntil(timeout: .seconds(5)) { done in
            pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 2)
                done()
            }
        }

        // Due to the second paragraph only containing whitespace
        // We should expect only 2 "addToNote" events
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 2)
    }

    func testMultipleShootsToDifferentCards() throws {
        let (pns, _) = testBed()

        // Add Paragraph 1 to Card 1
        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1</p>"
        )

        // Point
        pns.point(target: paragraphTarget)
        pns.draw()
        // Shoot
        pns.shoot(targets: [paragraphTarget], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()

        // Add shoot to note
        waitUntil(timeout: .seconds(5)) { done in
            pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                done()
            }
        }

        XCTAssertEqual(pns.shootGroups.count, 1)
        XCTAssertEqual(pns.shootGroups.first?.targets.count, 1)
        XCTAssertEqual(pns.shootGroups.first?.targets.first?.html, paragraphTarget.html)

        // Add Paragraph 2 to Card 2
        let paragraphTarget2: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph2</p>"
        )
        let page = self.testPage!
        page.activeNote = "Card B"
        page.testNotes["Card B"] = BeamNote(title: "Card B")

        // Point
        pns.point(target: paragraphTarget2)
        pns.draw()
        // Shoot
        pns.shoot(targets: [paragraphTarget2], href: pns.page.url!.string)
        pns.status = .shooting
        pns.draw()

        // Add shoot to note
        waitUntil(timeout: .seconds(5)) { done in
            pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                done()
            }
        }

        XCTAssertEqual(pns.shootGroups.count, 2)
        XCTAssertEqual(pns.shootGroups.last?.targets.count, 1)
        XCTAssertEqual(pns.shootGroups.last?.targets.last?.html, paragraphTarget2.html)

        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 2)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
