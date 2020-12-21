//
//  BeamTextTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import XCTest
@testable import Beam

extension String {
    var toBeamText: BeamText? {
        guard let data = self.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(BeamText.self, from: data)
    }
}

class BeamTextTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testBasicTextManipulations() {
        var btext = BeamText(text: "some string")
        XCTAssertEqual(btext.text, "some string")

        btext.insert("new ", at: 5)
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"some new string"}]}
        """.toBeamText)

        btext.insert("!", at: btext.text.count)
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"some new string!"}]}
        """.toBeamText)

        btext.insert("!", at: btext.text.count, withAttributes: [.strong])
        print("btext \(btext.json)")
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"some new string!"},{"string":"!","attributes":[{"type":0}]}]}
        """.toBeamText)

        btext.insert("BLEH ", at: 5, withAttributes: [.strong])
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"some "},{"string":"BLEH ","attributes":[{"type":0}]},{"string":"new string!"},{"string":"!","attributes":[{"type":0}]}]}
        """.toBeamText)

        btext.remove(count: 5, at: 0)
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"BLEH ","attributes":[{"type":0}]},{"string":"new string!"},{"string":"!","attributes":[{"type":0}]}]}
        """.toBeamText)

        btext.append(" done")
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"BLEH ","attributes":[{"type":0}]},{"string":"new string!"},{"string":"! done","attributes":[{"type":0}]}]}
        """.toBeamText)

        btext.removeSubrange(btext.wholeRange)
        XCTAssert(btext.isEmpty)
        XCTAssert(btext.text == "")
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":""}]}
        """.toBeamText)

        btext.insert("1", at: 0)
        XCTAssert(btext.text == "1")
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":"1"}]}
        """.toBeamText)

        btext.remove(count: 1, at: 0)
        XCTAssert(btext.text == "")
        XCTAssert(btext.isEmpty)
        XCTAssertEqual(btext,
        """
        {"ranges":[{"string":""}]}
        """.toBeamText)
    }

    func testRangeSplitting() {
        var text = BeamText(text: "some text")
        XCTAssertEqual(text.splitRangeAt(position: 0, createEmptyRanges: true), 1)
        XCTAssertEqual(text.ranges.count, 2)

        text = BeamText(text: "some text")
        XCTAssertEqual(text.splitRangeAt(position: 0, createEmptyRanges: false), 0)
        XCTAssertEqual(text.ranges.count, 1)

        text = BeamText(text: "some text")
        XCTAssertEqual(text.splitRangeAt(position: 9, createEmptyRanges: true), 1)
        XCTAssertEqual(text.ranges.count, 2)

        text = BeamText(text: "some text")
        XCTAssertEqual(text.splitRangeAt(position: 9, createEmptyRanges: false), 1)
        XCTAssertEqual(text.ranges.count, 1)
    }

    func testLoadFromJSon1() {
        guard let validText =
        """
        {"ranges":[{"string":"some "},{"string":"link","attributes":[{"type":4,"payload":"link"}]},{"string":" test"}]}
        """.toBeamText else { fatalError() }

        let links2 = validText.internalLinks
        XCTAssertEqual(links2.count, 1)
        XCTAssertEqual(links2[0].string, "link")
        XCTAssertEqual(links2[0].position, 5)
        XCTAssertEqual(links2[0].end, 9)
    }

    func testMakeLink1() {
        var text = BeamText(text: "some link test")
        XCTAssert(text.makeInternalLink(5..<9))

        let links1 = text.internalLinks
        XCTAssertEqual(links1.count, 1)
        XCTAssertEqual(links1[0].string, "link")
        XCTAssertEqual(links1[0].position, 5)
        XCTAssertEqual(links1[0].end, 9)

        guard let validText =
        """
        {"ranges":[{"string":"some "},{"string":"link","attributes":[{"type":4,"payload":"link"}]},{"string":" test"}]}
        """.toBeamText else { fatalError() }

        XCTAssertEqual(text, validText)
    }

    func testMakeLink2() {
        var text = BeamText(text: "some link test")
        XCTAssert(text.makeInternalLink(4..<9))

        let links1 = text.internalLinks
        XCTAssertEqual(links1.count, 1)
        XCTAssertEqual(links1[0].string, "link")
        XCTAssertEqual(links1[0].position, 5)
        XCTAssertEqual(links1[0].end, 9)

        guard let validText =
        """
        {"ranges":[{"string":"some "},{"string":"link","attributes":[{"type":4,"payload":"link"}]},{"string":" test"}]}
        """.toBeamText else { fatalError() }

        XCTAssertEqual(text, validText)
    }

    func testMakeLink3() {
        var text = BeamText(text: "some link test")
        XCTAssert(text.makeInternalLink(5..<10))

        let links1 = text.internalLinks
        XCTAssertEqual(links1.count, 1)
        XCTAssertEqual(links1[0].string, "link")
        XCTAssertEqual(links1[0].position, 5)
        XCTAssertEqual(links1[0].end, 9)

        guard let validText =
        """
        {"ranges":[{"string":"some "},{"string":"link","attributes":[{"type":4,"payload":"link"}]},{"string":" test"}]}
        """.toBeamText else { fatalError() }

        XCTAssertEqual(text, validText)
    }
}
