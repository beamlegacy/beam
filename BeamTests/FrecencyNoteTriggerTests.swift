//
//  FrecencyNoteTriggerTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 28/07/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore


class FrecencyNoteTriggerTests: XCTestCase {

    static let pnsNoteTitle = "Grocery list"
    static let pnsNote = BeamNote(title: pnsNoteTitle)

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
        func update(id: FrecencyScoreIdKey, value: Float, eventType: FrecencyEventType, date: Date, paramKey: FrecencyParamKey) {
            guard let id = id as? UUID else { return }
            let args = UpdateScoreArgs(id: id, scoreValue: value, eventType: eventType, date: date, paramKey: paramKey)
            updateCalls.append(args)
        }
    }

    class FakeBrowsingScorer: BrowsingScorer {
        var page: WebPage
        var currentScore: Score = Score()

        init(page: WebPage) {
            self.page = page
        }
        func updateScore() {}
        func addTextSelection() {}
        func applyLongTermScore(changes: (LongTermUrlScore) -> Void) {}
    }

    class FakeBeamWebViewConfiguration: BeamWebViewConfiguration {
            var id = UUID()
            func addCSS(source: String, when: WKUserScriptInjectionTime) {}
            func addJS(source: String, when: WKUserScriptInjectionTime) {}
            func obfuscate(str: String) -> String { return "" }
        }

    class FakeWebPage: WebPage {

        weak var webView: BeamWebView!

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
        var pointAndShootAllowed: Bool = false

        var title: String = ""
        var url: URL?

        var pointAndShoot: PointAndShoot?
        var navigationController: WebNavigationController?
        var browsingScorer: BrowsingScorer?
        var passwordOverlayController: PasswordOverlayController?
        var mediaPlayerController: MediaPlayerController?
        var appendToIndexer: ((URL, Readability) -> Void)?
        var score: Float = 0
        var authenticationViewModel: AuthenticationViewModel?
        var searchViewModel: SearchViewModel?

        func getNote(fromTitle: String) -> BeamNote? {
            if fromTitle == FrecencyNoteTriggerTests.pnsNoteTitle {
                return FrecencyNoteTriggerTests.pnsNote
            }
            return nil
        }

        func addToNote(allowSearchResult: Bool) -> BeamElement? {
            guard let url = url else {
                Logger.shared.logError("Cannot get current URL", category: .general)
                return nil
            }
            guard allowSearchResult || SearchEngines.get(url) != nil else {
                Logger.shared.logWarning("Adding search results is not allowed", category: .web)
                return nil
            } // Don't automatically add search results

            let element = BeamElement("url: \(url) text: \(title)")
            FrecencyNoteTriggerTests.pnsNote.addChild(element)
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
        XCTAssertEqual(scorer.updateCalls.count, 1)
        let call = scorer.updateCalls[0]
        XCTAssertEqual(call.id, note.id)
        XCTAssertEqual(call.scoreValue, 1.0)
        XCTAssertEqual(call.eventType, FrecencyEventType.noteVisit)
        XCTAssertEqual(call.paramKey, FrecencyParamKey.note30d0)
    }

    func testPointAndShootToNote() throws {
        let config = BrowserTabConfiguration()
        let webView = BeamWebView(frame: CGRect(), configuration: config)
        let page = FakeWebPage(webView: webView)
        page.url = URL(string: "http://www.amazon.gr")
        let pns = PointAndShoot(scorer: FakeBrowsingScorer(page: page))
        pns.data = data
        pns.page = page
        pns.activeShootGroup = PointAndShoot.ShootGroup("abc", [PointAndShoot.Target](), "abc")

        //When point and shooting to a note, frecency score of note gets updated
        XCTAssertEqual(scorer.updateCalls.count, 0)
        XCTAssertNotNil(pns.activeShootGroup)
        if let group = pns.activeShootGroup {
            let expectation = XCTestExpectation(description: "point and shoot addShootToNote")
            pns.addShootToNote(noteTitle: FrecencyNoteTriggerTests.pnsNoteTitle, group: group, completion: { [self] in
                XCTAssertEqual(scorer.updateCalls.count, 1)
                let call = scorer.updateCalls[0]
                XCTAssertEqual(call.id, FrecencyNoteTriggerTests.pnsNote.id)
                XCTAssertEqual(call.scoreValue, 1.0)
                XCTAssertEqual(call.eventType, FrecencyEventType.notePointAndShoot)
                XCTAssertEqual(call.paramKey, FrecencyParamKey.note30d0)
                expectation.fulfill()
            })
            wait(for: [expectation], timeout: 10.0)
        }
    }
}
