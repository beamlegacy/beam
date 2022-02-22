//
//  NoteBackForwardListTests.swift
//  BeamTests
//
//  Created by Remi Santos on 22/02/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class NoteBackForwardListTests: XCTestCase {

    var list: NoteBackForwardList!
    var noteA: BeamNote!

    override func setUp() {
        noteA = BeamNote(title: "Note A")
        list = NoteBackForwardList()
    }

    private func fillList(_ list: NoteBackForwardList) {
        list.push(.journal)
        list.push(.page(.allCardsWindowPage))
        list.push(.note(noteA))
        list.push(.journal)
    }

    func testGoBack() {
        fillList(list)
        XCTAssertEqual(list.backList.count, 3)
        XCTAssertEqual(list.forwardList.count, 0)
        let popped = list.goBack()
        XCTAssertEqual(popped, .note(noteA))
        XCTAssertEqual(list.backList.count, 2)
        XCTAssertEqual(list.backList.last, .page(.allCardsWindowPage))
        XCTAssertEqual(list.forwardList.count, 1)
    }

    func testGoForward() {
        fillList(list)
        XCTAssertEqual(list.backList.count, 3)
        XCTAssertEqual(list.forwardList.count, 0)
        let popped = list.goBack()
        XCTAssertEqual(popped, .note(noteA))
        XCTAssertEqual(list.backList.count, 2)
        XCTAssertEqual(list.forwardList.count, 1)

        let poppedForward = list.goForward()
        XCTAssertEqual(poppedForward, .journal)
        XCTAssertEqual(list.backList.count, 3)
        XCTAssertEqual(list.forwardList.count, 0)
    }

    func testPurgeDeletedNote() {
        fillList(list)
        list.purgeDeletedNote(withId: noteA.id)
        XCTAssertEqual(list.backList.count, 2)
        XCTAssertEqual(list.backList.last, .page(.allCardsWindowPage))
    }

    func testPurgeDeletedNoteCleanDuplicates() {
        fillList(list)
        list.push(.journal)
        list.push(.note(noteA))
        list.push(.journal)
        // once noteA delete, two consecutive .journal are detected and cleaned up into one.
        list.purgeDeletedNote(withId: noteA.id)
        XCTAssertEqual(list.backList.count, 2)
        XCTAssertEqual(list.backList.last, .page(.allCardsWindowPage))
    }
}
