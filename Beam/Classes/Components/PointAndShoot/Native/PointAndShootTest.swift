import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class TestWebPage: WebPage {
    var events: [String] = []
    var scrollX: CGFloat = 0
    var scrollY: CGFloat = 0
    private(set) var originalQuery: String?
    private(set) var pointAndShootAllowed: Bool = true
    private(set) var title: String = "PNS MockPage"
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
    var activeNote: String = "Card A"
    var testNotes: [String: BeamCore.BeamNote] = ["Card A": BeamNote(title: "Card A")]
    var fileStorage: BeamFileStorage {
        storage
    }

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
}

class PointAndShootUIMock: PointAndShootUI {
    var events: [String] = []

    override func drawPoint(target: PointAndShoot.Target) {
        events.append("drawPoint \(target)")
    }

    override func clearPoint() {
        events.append("clearPoint")
        return super.clearPoint()
    }

    override func createUI(shootTarget: PointAndShoot.Target) -> SelectionUI {
        events.append("createUI \(shootTarget)")
        return super.createUI(shootTarget: shootTarget)
    }

    override func createGroup(noteInfo: NoteInfo, selectionUIs: [SelectionUI], edited: Bool) -> ShootGroupUI {
        events.append("createGroup \(String(describing: noteInfo)) \(edited)")
        return super.createGroup(noteInfo: noteInfo, selectionUIs: selectionUIs, edited: edited)
    }

    override func drawShootConfirmation(shootTarget: PointAndShoot.Target, noteInfo: NoteInfo) {
        events.append("drawShootConfirmation \(shootTarget)")
        return super.drawShootConfirmation(shootTarget: shootTarget, noteInfo: noteInfo)
    }

    override func clearShoots() {
        events.append("clearShoots")
        return super.clearShoots()
    }

    override func clearConfirmation() {
        events.append("clearConfirmation")
        return super.clearConfirmation()
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
    private(set) var currentScore: BeamCore.Score = Score()

    override init() {
        super.init()
    }

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
    var pns: PointAndShoot!
    var testUI: PointAndShootUIMock!

    func initTestBed() {
        let testPasswordStore = PasswordStoreMock()
        let userInfoStore = MockUserInformationsStore()
        let testPasswordOverlayController = PasswordOverlayController(passwordStore: testPasswordStore, userInfoStore: userInfoStore, passwordManager: .shared)
        let testBrowsingScorer = BrowsingScorerMock()
        self.testUI = PointAndShootUIMock()

        let testFileStorage = FileStorageMock()
        let testDownloadManager = DownloadManagerMock()
        self.pns = PointAndShoot(ui: testUI, scorer: testBrowsingScorer)
        let page = TestWebPage(browsingScorer: testBrowsingScorer,
                               passwordOverlayController: testPasswordOverlayController, pns: pns,
                               fileStorage: testFileStorage, downloadManager: testDownloadManager)
        self.testPage = page
        page.browsingScorer.page = page
        page.passwordOverlayController.page = page
        page.pointAndShoot.page = page
    }

    func helperCountUIEvents(_ label: String) -> Int {
        return self.testUI.events.filter({ $0.contains(label) }).count
    }

    // Note: this class is only used to setup the Point and Shoot Mocks and testbed
}
