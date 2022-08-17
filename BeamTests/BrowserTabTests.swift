//
//  BrowserTabTests.swift
//  BeamTests
//
//  Created by Stef Kors on 10/01/2022.
//

import XCTest

@testable import Beam
@testable import BeamCore

class BrowserTabTests: XCTestCase {
    var note: BeamNote!
    var tab: BrowserTab!

    override func setUpWithError() throws {
        note = try BeamNote(title: "Sample note")
        tab = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .note, note: note)
    }

    func testTabInit_AssignsNoteToNoteController() throws {
        XCTAssertEqual(tab.noteController.note, note)
    }
    func testPinnedInit() throws {
        let url = URL(string: "http://elmundo.es")!
        let tab = BrowserTab(pinnedTabWithId: UUID(), url: url, title: "El journal")
        XCTAssert(tab.browsingTree.isPinned)
        tab.isPinned = false
        XCTAssertFalse(tab.browsingTree.isPinned)
    }

    func testEncodeTab() throws {
        let url = URL(string: "http://elmundo.es")!
        let tab = BrowserTab(pinnedTabWithId: UUID(), url: url, title: "El journal")
        let data = try PropertyListEncoder().encode(tab)
        let decodedTab = try PropertyListDecoder().decode(BrowserTab.self, from: data)

        XCTAssert(decodedTab.preloadUrl == url)
        XCTAssert(decodedTab.browsingTree.isFrecencyActive)
    }

    func testPerformance_InitTab() throws {
        self.measure {
            let _ = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .note, note: note)
        }
    }
}
