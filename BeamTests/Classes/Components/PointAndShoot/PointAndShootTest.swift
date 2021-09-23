import XCTest
import Promises
import Nimble
import Fakery

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
    var pointAndShoot: PointAndShoot?
    var browsingScorer: BrowsingScorer?
    var storage: BeamFileStorage?
    var passwordOverlayController: PasswordOverlayController?
    private(set) var webviewWindow: NSWindow?
    private(set) var frame: NSRect = NSRect(x: 0, y: 0, width: 600, height: 800)
    private(set) var mouseLocation: NSPoint!
    private(set) var downloadManager: DownloadManager?
    private(set) var navigationController: WebNavigationController?
    var mediaPlayerController: MediaPlayerController?
    var appendToIndexer: ((URL, Readability) -> Void)?
    var webView: BeamWebView!
    var activeNote: String = "Card A"
    var testNotes: [String: BeamCore.BeamNote] = ["Card A": BeamNote(title: "Card A")]
    var fileStorage: BeamFileStorage? {
        storage
    }
    var authenticationViewModel: AuthenticationViewModel?
    var searchViewModel: SearchViewModel?

    init(browsingScorer: BrowsingScorer?, passwordOverlayController: PasswordOverlayController?, pns: PointAndShoot?,
         fileStorage: BeamFileStorage?, downloadManager: DownloadManager?, navigationController: WebNavigationController?) {
        self.browsingScorer = browsingScorer
        self.passwordOverlayController = passwordOverlayController
        pointAndShoot = pns
        storage = fileStorage
        self.downloadManager = downloadManager
        self.navigationController = navigationController
        self.webView = BeamWebView()
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addCSS \(source.hashValue) \(String(describing: when))")
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addJS \(source.hashValue) \(String(describing: when))")
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage {
        events.append("createNewTab \(targetURL) \(setCurrent))")
        return TestWebPage(browsingScorer: browsingScorer, passwordOverlayController: passwordOverlayController, pns: pointAndShoot,
                           fileStorage: storage, downloadManager: downloadManager, navigationController: navigationController)
    }

    func createNewWindow(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        events.append("createNewWindow \(targetURL) \(setCurrent))")
        let webPage = TestWebPage(browsingScorer: browsingScorer, passwordOverlayController: passwordOverlayController, pns: pointAndShoot,
                                  fileStorage: storage, downloadManager: downloadManager, navigationController: navigationController)
        return webPage.webView
    }

    func isActiveTab() -> Bool {
        true
    }

    func leave() {
        events.append("leave")
    }

    func navigatedTo(url: URL, title: String, isNavigation: Bool) {
        events.append("navigatedTo \(url) \(title)")
        self.url = url
        self.title = title
        self.logInNote(url: url, title: title, reason: .pointandshoot)
    }

    func executeJS(_ jsCode: String, objectName: String?) -> Promise<Any?> {
        if objectName == "PointAndShoot" {
            Logger.shared.logDebug("no matching jsCode case, no js call mocked", category: .pointAndShoot)
        }
        events.append("executeJS \(objectName ?? "").\(jsCode)")
        return Promise(true)
    }

    func logInNote(url: URL, title: String?, reason: NoteElementAddReason) {
        events.append("logInNote \(url) \(title ?? "") \(reason)")
    }

    func addToNote(allowSearchResult: Bool) -> BeamCore.BeamElement? {
        events.append("addToNote \(allowSearchResult)")
        if let url = self.url {
            self.logInNote(url: url, title: self.title, reason: .pointandshoot)
        }
        // use last note
        return testNotes[activeNote]
    }

    func closeTab() {
        events.append("closeTab")
    }

    func setDestinationNote(_ note: BeamCore.BeamNote, rootElement: BeamCore.BeamElement?) {
        events.append("setDestinationNote \(note) \(String(describing: rootElement))")
    }

    func getNote(fromTitle: String) -> BeamCore.BeamNote? {
        events.append("getNote \(fromTitle)")
        return testNotes[fromTitle]
    }

    func addTextToClusteringManager(_ text: String, url: URL) {}
}

class MockUserInformationsStore: UserInformationsStore {

    func save(userInfo: UserInformations) {}
    func update(userInfoUUIDToUpdate: UUID, updatedUserInformations: UserInformations) {}

    func fetchAll() -> [UserInformations] {
        return [UserInformations( country: 2, organization: "Beam", firstName: "John", lastName: "Beam", adresses: "123 Rue de Beam", postalCode: "69001", city: "BeamCity", phone: "0606060606", email: "john@beamapp.co")]
    }

    func fetchFirst() -> UserInformations {
        return UserInformations( country: 2, organization: "Beam", firstName: "John", lastName: "Beam", adresses: "123 Rue de Beam", postalCode: "69001", city: "BeamCity", phone: "0606060606", email: "john@beamapp.co")
    }

    func delete(id: UUID) {}
}

class BrowsingScorerMock: WebPageHolder, BrowsingScorer {
    private(set) var currentScore: BeamCore.Score = Score()

    override init() {
        super.init()
    }

    func updateScore() {}

    func addTextSelection() {}

    func applyLongTermScore(changes: (LongTermUrlScore) -> Void) {}
}

class FileStorageMock: BeamFileStorage {
    var events: [String] = []

    func fetch(uid: UUID) throws -> BeamFileRecord? { fatalError("fetch(uid:) has not been implemented") }

    func insert(name: String, data: Data, type: String?) throws -> UUID {
        let uid = UUID.v5(name: data.SHA256, namespace: .url)
        events.append("inserted \(name) with id \(uid) of \(String(describing: type)) for \(data.count) bytes")
        return uid
    }

    func remove(uid: UUID) throws {}

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

    func downloadFile(at url: URL, headers: [String: String], suggestedFileName: String?, destinationFoldedURL: URL?) {}
    func downloadFile(from document: BeamDownloadDocument) throws {}

    func clearAllFileDownloads() {}
    func clearFileDownload(_ download: Download) -> Download? { return nil }

    func downloadImage(_ src: URL, pageUrl: URL, completion: @escaping ((Data, String)?) -> Void) {
        let headers = ["Referer": pageUrl.absoluteString]
        self.downloadURL(src, headers: headers) { result in
            guard case .binary(let data, let mimeType, _) = result,
                  data.count > 0 else {
                Logger.shared.logError("Failed downloading Image from \(src)", category: .pointAndShoot)
                completion(nil)
                return
            }
            completion((data, mimeType))
        }
    }
    func waitForDownloadURL(_ url: URL, headers: [String: String]) -> DownloadManagerResult? { fatalError("waitForDownloadURL(_:headers:) has not been implemented") }
}

class NavigationControllerMock: WebNavigationController {
    var events: [String] = []

    func navigatedTo(url: URL, webView: WKWebView, replace: Bool) {
        events.append("navigatedTo \(url) \(replace)")
    }

    func setLoading() {
        events.append("setLoading")
    }

}

class PointAndShootTest: XCTestCase {
    var testPage: TestWebPage?
    var pns: PointAndShoot!

    func initTestBed() {
        let userInfoStore = MockUserInformationsStore()
        let testPasswordOverlayController = PasswordOverlayController(userInfoStore: userInfoStore)
        let testBrowsingScorer = BrowsingScorerMock()

        let testFileStorage = FileStorageMock()
        let testDownloadManager = DownloadManagerMock()
        let navigationController = NavigationControllerMock()
        pns = PointAndShoot(scorer: testBrowsingScorer)
        let page = TestWebPage(browsingScorer: testBrowsingScorer,
                               passwordOverlayController: testPasswordOverlayController, pns: pns,
                               fileStorage: testFileStorage, downloadManager: testDownloadManager,
                               navigationController: navigationController)
        testPage = page
        page.browsingScorer?.page = page
        page.passwordOverlayController?.page = page
        page.pointAndShoot?.page = page
    }

    let faker = Faker(locale: "en-US")
    func helperCreateRandomGroups() -> PointAndShoot.ShootGroup {
        let count = faker.number.randomInt(min: 1, max: 12)
        return self.helperCreateRandomGroupCount(count)
    }

    func helperCreateRandomGroupCount(_ count: Int) -> PointAndShoot.ShootGroup {
        var targets: [PointAndShoot.Target] = []

        for _ in 0..<count {
            let target = PointAndShoot.Target(
                id: UUID().uuidString,
                rect: NSRect(
                    x: faker.number.randomInt(),
                    y: faker.number.randomInt(),
                    width: faker.number.randomInt(),
                    height: faker.number.randomInt()
                ),
                mouseLocation: NSPoint(x: faker.number.randomInt(), y: faker.number.randomInt()),
                html: "<p>\(faker.hobbit.quote())</p>",
                animated: false
            )
            targets.append(target)
        }

        return PointAndShoot.ShootGroup(UUID().uuidString, targets, faker.internet.url())
    }

    // Note: this class is only used to setup the Point and Shoot Mocks and testbed
}
