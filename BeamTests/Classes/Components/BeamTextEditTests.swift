//
//  BeamTextEditTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 06/09/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

class BeamTextEditTests: XCTestCase {
    var note: BeamNote!
    var data: BeamData!
    var editor: BeamTextEdit!
    let previousNetworkEnabled = Configuration.networkEnabled

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        BeamData.shared.currentAccount?.logout()
        Configuration.networkEnabled = false

        data = BeamData()
        note = try BeamNote(title: "BeamTextEditTests")
        note.owner = BeamData.shared.currentDatabase
        editor = BeamTextEdit(root: note, journalMode: false, enableDelayedInit: false)
        editor.data = data
        editor.prepareRoot()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        Configuration.networkEnabled = previousNetworkEnabled
    }

    func testLinkStringForPrecedingCharacters() {
        let root = editor.rootNode!

        let bullet = BeamElement("Some text and a link.com")
        let node = TextNode(parent: root, element: bullet, availableWidth: 600)

        XCTAssertNil(editor.linkStringForPrecedingCharacters(atIndex: 10, in: node))

        let result = editor.linkStringForPrecedingCharacters(atIndex: node.textCount, in: node)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, "https://link.com")
        XCTAssertEqual(result?.1, node.textCount-8 ..< node.textCount)
    }
}
