//
//  BeamElementLinks.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 09/07/2021.
//

import XCTest
import Foundation
@testable import BeamCore
@testable import Beam

class BeamElementLinks: XCTestCase {

    override func setUpWithError() throws {
        BeamTestsHelper.logout()
        try AppData.shared.clearAllAccountsAndSetupDefaultAccount()
    }

    override func tearDownWithError() throws {
        try AppData.shared.clearAllAccountsAndSetupDefaultAccount()
    }

    func testLink1() throws {
        let linkedNote1 = try BeamNote(title: "note1")
        let linkedNote2 = try BeamNote(title: "note2")
        let linkedNote3 = try BeamNote(title: "note3")
        let linkedNote4 = try BeamNote(title: "note4")
        linkedNote1.owner = BeamData.shared.currentDatabase
        linkedNote2.owner = BeamData.shared.currentDatabase
        linkedNote3.owner = BeamData.shared.currentDatabase
        linkedNote4.owner = BeamData.shared.currentDatabase
        let id1 = linkedNote1.id
        let id2 = linkedNote2.id
        let id3 = linkedNote3.id
        let id4 = linkedNote4.id
        var text1 = BeamText(text: "test hop bleh")
        text1.addAttributes([.internalLink(id1)], to: 5..<9)
        text1.addAttributes([.internalLink(id2)], to: 10..<15)
        var text2 = BeamText(text: "fun foo")
        text2.addAttributes([.internalLink(id3)], to: 0..<3)
        text2.addAttributes([.internalLink(id4)], to: 4..<8)

        let note = try BeamNote(title: "testNote")
        let element1 = BeamElement(text1)
        let element2 = BeamElement(text2)
        note.addChild(element1)
        element1.addChild(element2)

        let links = note.internalLinks
        XCTAssert(links.count == 4)

        let link1 = BidirectionalLink(sourceNoteId: note.id, sourceElementId: element1.id, linkedNoteId: id1)
        let link2 = BidirectionalLink(sourceNoteId: note.id, sourceElementId: element1.id, linkedNoteId: id2)
        let link3 = BidirectionalLink(sourceNoteId: note.id, sourceElementId: element2.id, linkedNoteId: id3)
        let link4 = BidirectionalLink(sourceNoteId: note.id, sourceElementId: element2.id, linkedNoteId: id4)
        XCTAssert(links.contains(link1))
        XCTAssert(links.contains(link2))
        XCTAssert(links.contains(link3))
        XCTAssert(links.contains(link4))

        BeamData.shared.noteLinksAndRefsManager?.appendLink(link1)
        BeamData.shared.noteLinksAndRefsManager?.appendLink(link2)
        BeamData.shared.noteLinksAndRefsManager?.appendLink(link3)
        BeamData.shared.noteLinksAndRefsManager?.appendLink(link4)

        let dbLinks1 = linkedNote1.links
        XCTAssertEqual(dbLinks1.count, 1)
        XCTAssert(dbLinks1.contains(link1.reference))

        let dbLinks2 = linkedNote2.links
        XCTAssertEqual(dbLinks2.count, 1)
        XCTAssert(dbLinks2.contains(link2.reference))

        let dbLinks3 = linkedNote3.links
        XCTAssertEqual(dbLinks3.count, 1)
        XCTAssert(dbLinks3.contains(link3.reference))

        let dbLinks4 = linkedNote4.links
        XCTAssertEqual(dbLinks4.count, 1)
        XCTAssert(dbLinks4.contains(link4.reference))
    }
}
