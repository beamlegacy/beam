import XCTest
import Promises
import Nimble
import Fakery
import Combine

@testable import Beam
@testable import BeamCore

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
        let testPasswordOverlayController = WebAutofillController(userInfoStore: userInfoStore)
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
        page.webAutofillController?.page = page
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
