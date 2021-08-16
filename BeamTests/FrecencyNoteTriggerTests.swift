//
//  FrecencyNoteTriggerTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 28/07/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

private var pnsNoteTitle = "Grocery list"
private var pnsNote = BeamNote(title: pnsNoteTitle)

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
        var passwordDB: PasswordsDB?
        var authenticationViewModel: AuthenticationViewModel?

        func getNote(fromTitle: String) -> BeamNote? {
            if fromTitle == pnsNoteTitle {
                return pnsNote
            }
            return nil
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
        pns.addShootToNote(noteTitle: pnsNoteTitle)
        XCTAssertEqual(scorer.updateCalls.count, 1)
        let call = scorer.updateCalls[0]
        XCTAssertEqual(call.id, pnsNote.id)
        XCTAssertEqual(call.scoreValue, 1.0)
        XCTAssertEqual(call.eventType, FrecencyEventType.notePointAndShoot)
        XCTAssertEqual(call.paramKey, FrecencyParamKey.note30d0)
    }
}
