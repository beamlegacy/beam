//
//  FrecencyNoteTriggerTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 28/07/2021.
//

import XCTest
import Combine

@testable import Beam
@testable import BeamCore


fileprivate var pnsNoteTitle = "Grocery list"
fileprivate var pnsNote = BeamNote(title: pnsNoteTitle)

class FrecencyNoteTriggerTests: XCTestCase {

    var scorer: FakeFrecencyScorer!
    var data: BeamData!


    struct UpdateScoreArgs {
        let id: UUID
        let scoreValue: Float
        let eventType: FrecencyEventType
        let date: Date
        let paramKey: FrecencyParamKey
    }

    class FakeFrecencyScorer: FrecencyScorer {
        public var updateCalls = [UpdateScoreArgs]()
        func update(id: UUID, value: Float, eventType: FrecencyEventType, date: Date, paramKey: FrecencyParamKey) {
            let args = UpdateScoreArgs(id: id, scoreValue: value, eventType: eventType, date: date, paramKey: paramKey)
            updateCalls.append(args)
        }
    }

    class FakeBrowsingScorer: BrowsingScorer {
        var debouncedUpdateScrollingScore = PassthroughSubject<WebFrames.FrameInfo, Never>()
        weak var page: WebPage?
        var currentScore: Score = Score()

        init(page: WebPage) {
            self.page = page
        }
        func updateScore() {}
        func addTextSelection() {}
        func scoreApply(changes: (UrlScoreProtocol) -> Void) {}
        func updateScrollingScore(_ frame: WebFrames.FrameInfo) {}
    }

    class FakeWebPage: WebPage {

        var webView: BeamWebView

        init(webView: BeamWebView) {
            self.webView = webView
        }

        var downloadManager: DownloadManager?
        var webviewWindow: NSWindow?
        var fileStorage: BeamFileStorage?

        var frame: NSRect = .zero
        var scrollX: CGFloat = .zero
        var scrollY: CGFloat = .zero
        var originalQuery: String?
        var pointAndShootInstalled: Bool = false
        var pointAndShootEnabled: Bool = false
        var hasError: Bool = false
        var responseStatusCode: Int = 200

        var title: String = ""
        var url: URL?
        var requestedURL: URL?

        var webFrames: WebFrames?
        var webPositions: WebPositions?
        var pointAndShoot: PointAndShoot?
        var navigationController: WebNavigationController?
        var browsingScorer: BrowsingScorer?
        var passwordOverlayController: PasswordOverlayController?
        var mediaPlayerController: MediaPlayerController?
        var appendToIndexer: ((URL, _ title: String, Readability) -> Void)?
        var score: Float = 0
        var contentDescription: BrowserContentDescription?
        var authenticationViewModel: AuthenticationViewModel?
        var searchViewModel: SearchViewModel?
        var errorPageManager: ErrorPageManager?
        var mouseHoveringLocation: MouseHoveringLocation = .none

        func getNote(fromTitle: String) -> BeamNote? {
            if fromTitle == pnsNoteTitle {
                return pnsNote
            }
            return nil
        }

        func addToNote(allowSearchResult: Bool, inSourceBullet: Bool = true) -> BeamElement? {
            guard let url = url else {
                Logger.shared.logError("Cannot get current URL", category: .general)
                return nil
            }
            guard allowSearchResult || SearchEngineProvider.provider(for: url) != nil else {
                Logger.shared.logWarning("Adding search results is not allowed", category: .web)
                return nil
            } // Don't automatically add search results

            let element = BeamElement("url: \(url) text: \(title)")
            pnsNote.addChild(element)
            return element

        }

    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        scorer = FakeFrecencyScorer()
        data = BeamData()
        data.noteFrecencyScorer = scorer
    }

    func testNavigateToNote() throws {
        let state = BeamState()
        state.data = data
        let note = BeamNote(title: "Amazing Thoughts")

        //When navigating to a note, frecency score of note gets updated
        XCTAssertEqual(scorer.updateCalls.count, 0)
        state.navigateToNote(note)
        XCTAssertEqual(scorer.updateCalls.count, 2)
        let call = scorer.updateCalls[0]
        XCTAssertEqual(call.id, note.id)
        XCTAssertEqual(call.scoreValue, 1.0)
        XCTAssertEqual(call.eventType, FrecencyEventType.noteVisit)
        XCTAssertEqual(call.paramKey, FrecencyParamKey.note30d0)
    }

    func testPointAndShootToNote() throws {
        let config = BeamWebViewConfigurationBase()
        let webView = BeamWebView(frame: CGRect(), configuration: config)
        let page = FakeWebPage(webView: webView)
        page.url = URL(string: "http://www.amazon.gr")
        let pns = PointAndShoot()
        pns.data = data
        pns.page = page
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: "id",
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        pns.activeShootGroup = PointAndShoot.ShootGroup(id: "abc", targets: [target], text: "placeholder", href: "abc", shapeCache: .init())

        //When point and shooting to a note, frecency score of note gets updated
        XCTAssertEqual(scorer.updateCalls.count, 0)
        XCTAssertNotNil(pns.activeShootGroup)
        if let group = pns.activeShootGroup {
            let expectation = XCTestExpectation(description: "point and shoot addShootToNote")
            pns.addShootToNote(targetNote: pnsNote, group: group, completion: {
                XCTAssertEqual(self.scorer.updateCalls.count, 2)
                let call = self.scorer.updateCalls[0]
                XCTAssertEqual(call.id, pnsNote.id)
                XCTAssertEqual(call.scoreValue, 1.0)
                XCTAssertEqual(call.eventType, FrecencyEventType.notePointAndShoot)
                XCTAssertEqual(call.paramKey, FrecencyParamKey.note30d0)
                expectation.fulfill()
            })
            wait(for: [expectation], timeout: 10.0)
        }
    }
}
