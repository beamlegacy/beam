import XCTest
import Promises
import Nimble
import Fakery
import Combine

@testable import Beam
@testable import BeamCore

class TestWebPage: WebPage {
    var events: [String] = []
    private(set) var originalQuery: String?
    private(set) var pointAndShootInstalled: Bool = true
    private(set) var pointAndShootEnabled: Bool = true
    private(set) var title: String = "PNS MockPage"
    static let urlStr = "https://webpage.com"
    var url: URL? = URL(string: urlStr)
    var requestedURL: URL?
    var score: Float = 0
    var pointAndShoot: PointAndShoot?
    var webFrames: WebFrames?
    var webPositions: WebPositions?
    var browsingScorer: BrowsingScorer?
    var storage: BeamFileStorage?
    var passwordOverlayController: PasswordOverlayController?
    var errorPageManager: ErrorPageManager?
    private(set) var webviewWindow: NSWindow?
    private(set) var frame: NSRect = NSRect(x: 0, y: 0, width: 600, height: 800)
    private(set) var mouseLocation: NSPoint!
    private(set) var downloadManager: DownloadManager?
    private(set) var webViewNavigationHandler: WebViewNavigationHandler?
    var hasError: Bool = false
    var responseStatusCode: Int = 200
    var mediaPlayerController: MediaPlayerController?
    var webView: BeamWebView
    var activeNote: BeamNote {
        if let note = testNotes.values.first {
            return note
        } else {
            return BeamNote(title: "activeNote backup")
        }
    }
    var testNotes: [String: BeamCore.BeamNote] = ["Note A": BeamNote(title: "Note A")]
    var fileStorage: BeamFileStorage? {
        storage
    }
    var contentDescription: BrowserContentDescription?
    var authenticationViewModel: AuthenticationViewModel?
    var searchViewModel: SearchViewModel?
    var mouseHoveringLocation: MouseHoveringLocation = .none

    init(browsingScorer: BrowsingScorer?, passwordOverlayController: PasswordOverlayController?, pns: PointAndShoot?,
         fileStorage: BeamFileStorage?, downloadManager: DownloadManager?, navigationHandler: WebViewNavigationHandler?) {
        self.browsingScorer = browsingScorer
        self.passwordOverlayController = passwordOverlayController
        pointAndShoot = pns
        storage = fileStorage
        self.downloadManager = downloadManager
        self.webViewNavigationHandler = navigationHandler
        self.webView = BeamWebView()
        let webFrames = WebFrames()
        self.webFrames = webFrames
        self.webPositions = WebPositions(webFrames: webFrames)
        contentDescription = WebContentDescription(webView: webView)
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addCSS \(source.hashValue) \(String(describing: when))")
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        events.append("addJS \(source.hashValue) \(String(describing: when))")
    }

    func createNewTab(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, setCurrent: Bool) -> WebPage? {
        events.append("createNewTab \(targetURL) \(setCurrent))")
        return TestWebPage(browsingScorer: browsingScorer, passwordOverlayController: passwordOverlayController, pns: pointAndShoot,
                           fileStorage: storage, downloadManager: downloadManager, navigationHandler: webViewNavigationHandler)
    }

    func createNewWindow(_ targetURL: URL, _ configuration: WKWebViewConfiguration?, windowFeatures: WKWindowFeatures, setCurrent: Bool) -> BeamWebView {
        events.append("createNewWindow \(targetURL) \(setCurrent))")
        let webPage = TestWebPage(browsingScorer: browsingScorer, passwordOverlayController: passwordOverlayController, pns: pointAndShoot,
                                  fileStorage: storage, downloadManager: downloadManager, navigationHandler: webViewNavigationHandler)

        return webPage.webView
    }

    func isActiveTab() -> Bool {
        true
    }

    func leave() {
        events.append("leave")
    }

    func shouldNavigateInANewTab(url: URL) -> Bool { false }

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

    func addToNote(allowSearchResult: Bool, inSourceBullet: Bool = true) -> BeamCore.BeamElement? {
        events.append("addToNote \(allowSearchResult)")
        if let url = self.url {
            self.logInNote(url: url, title: self.title, reason: .pointandshoot)
        }
        // use last note
        return activeNote
    }

    func closeTab() {
        events.append("closeTab")
    }

    func setDestinationNote(_ note: BeamCore.BeamNote, rootElement: BeamCore.BeamElement?) {
        events.append("setDestinationNote \(note.title) \(String(describing: rootElement))")
    }

    func getNote(fromTitle: String) -> BeamCore.BeamNote? {
        events.append("getNote \(fromTitle)")
        return testNotes[fromTitle] ?? nil
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

class BrowsingScorerMock: NSObject, WebPageRelated, BrowsingScorer {
    weak var page: WebPage?
    var debouncedUpdateScrollingScore = PassthroughSubject<WebFrames.FrameInfo, Never>()
    private(set) var currentScore: BeamCore.Score = Score()

    override init() {
        super.init()
    }

    func updateScore() {}

    func addTextSelection() {}

    func scoreApply(changes: (UrlScoreProtocol) -> Void) {}
    func updateScrollingScore(_ frame: WebFrames.FrameInfo) {}
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

    func addReference(fromNote: UUID, element: UUID, to: UUID) throws {}
    func removeReference(fromNote: UUID, element: UUID?, to: UUID?) throws {}
    func referenceCount(fileId: UUID) throws -> Int { 0 }

    func referencesFor(fileId: UUID) throws -> [BeamNoteReference] { [] }

    func purgeUnlinkedFiles() throws {}
    func purgeUndo() throws {}
    func clearFileReferences() throws {}
}

class DownloadManagerMock: DownloadManager {
    var events: [String] = []

    var fractionCompleted: Double = 0.0
    var overallProgress: Progress = Progress()
    var downloadList = DownloadList<DownloadItem>()

    func download(_ download: WKDownload) {}

    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void) {}

    func downloadURL(_ url: URL, headers: [String: String], completion: @escaping (DownloadManagerResult) -> Void) {
        events.append("downloaded \(url.absoluteString) with headers \(headers)")
        completion(DownloadManagerResult.binary(data: Data([0x01, 0x02, 0x03]), mimeType: "image/png", actualURL: URL(string: "https://webpage.com/image.png")!))
    }

    func downloadFile(from document: BeamDownloadDocument) throws {}

    func clearAllFileDownloads() {}
    func clearFileDownload(_ download: DownloadItem) -> DownloadItem? { return nil }

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

class NavigationHandlerMock: WebViewNavigationHandler {
    var events: [String] = []

    func webViewIsInstructedToLoadURLFromUI(_ url: URL) { }

    func webView(_ webView: WKWebView, willPerformNavigationAction action: WKNavigationAction) { }

    func webView(_ webView: WKWebView, didReachURL url: URL) { }

    func webView(_ webView: WKWebView, didFinishNavigationToURL url: URL, source: WebViewControllerNavigationSource) {
        var replace = false
        if case .javascript(let replacing) = source {
            replace = replacing
        }
        events.append("navigatedTo \(url) \(replace)")
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
        let navigationHandler = NavigationHandlerMock()
        pns = PointAndShoot()
        let page = TestWebPage(browsingScorer: testBrowsingScorer,
                               passwordOverlayController: testPasswordOverlayController, pns: pns,
                               fileStorage: testFileStorage, downloadManager: testDownloadManager,
                               navigationHandler: navigationHandler)
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

        return PointAndShoot.ShootGroup(id: UUID().uuidString, targets: targets, text: "placeholder text", href: faker.internet.url(), shapeCache: .init())
    }

    // Note: this class is only used to setup the Point and Shoot Mocks and testbed
}
