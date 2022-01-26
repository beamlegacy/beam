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
        note = BeamNote(title: "Sample note")
        tab = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .note, note: note)
    }

    func testTabInit_AssignsNoteToNoteController() throws {
        XCTAssertEqual(tab.noteController.note, note)
    }

    func testPerformance_InitTab() throws {
        self.measure {
            let _ = BrowserTab(state: BeamState(), browsingTreeOrigin: nil, originMode: .note, note: note)
        }
    }
}
