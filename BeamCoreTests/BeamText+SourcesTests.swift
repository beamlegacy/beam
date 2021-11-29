//
//  BeamText+SourcesTests.swift
//  BeamCoreTests
//
//  Created by Stef Kors on 25/11/2021.
//

import XCTest
import Foundation
@testable import BeamCore

class BeamTextSourcesTests: XCTestCase {
    var text: BeamText!

    override func setUpWithError() throws {
        self.text = BeamText(text: "text hop bleh")
    }

    func testGetAllSources() throws {
        let source = SourceMetadata(string: "https://en.wikipedia.org/wiki/Lama_(genus)")
        text.addAttributes([.source(source)], to: 5..<9)

        XCTAssertEqual(text.sources.count, 1)
        XCTAssert(text.sources.contains(source))
    }

    func testGetAllSourceRanges() throws {
        let source = SourceMetadata(string: "https://en.wikipedia.org/wiki/Lama_(genus)")
        let sourceRange = 5..<9
        text.addAttributes([.source(source)], to: sourceRange)

        XCTAssertEqual(text.sourceRanges.count, 1)
        if let range = text.sourceRanges.first {
            XCTAssertEqual(range.range, sourceRange)
        } else {
            XCTFail("expected atleast one range")
        }
    }

    func testRemoveSourceRanges() throws {
        let urlString = "https://en.wikipedia.org/wiki/Lama_(genus)"
        let source = SourceMetadata(string: urlString)

        let inputAttributes = [BeamText.Attribute.source(source), BeamText.Attribute.link(urlString)]
        let outputAttributes = BeamText.removeSources(from: inputAttributes)

        XCTAssertEqual(inputAttributes.count, 2)
        XCTAssertEqual(outputAttributes, [BeamText.Attribute.link(urlString)])
    }

    func testHasSourceToNote() throws {
        let title = "Original Note Title"
        let uuid = UUID()
        let sourceRange = 5..<9

        let source = SourceMetadata(origin: .local(uuid), title: title)
        text.addAttributes([.source(source)], to: sourceRange)

        for count in 0..<7 {
            text.addAttributes([.source(SourceMetadata(origin: .local(UUID())))], to: count..<9)
        }

        XCTAssertEqual(text.sourceRanges.count, 7)
        XCTAssertTrue(text.hasSourceToNote(id: uuid))
        XCTAssertFalse(text.hasSourceToNote(id: UUID()))
    }

    func testHasSourceToWeb() throws {
        let title = "Original Note Title"
        let url = URL(string: "https://en.wikipedia.org/wiki/Lama_(genus)")!
        let sourceRange = 5..<9

        let source = SourceMetadata(origin: .remote(url), title: title)
        text.addAttributes([.source(source)], to: sourceRange)

        for count in 0..<7 {
            text.addAttributes([.source(SourceMetadata(origin: .local(UUID())))], to: count..<9)
        }

        XCTAssertEqual(text.sourceRanges.count, 7)
        XCTAssertTrue(text.hasSourceToWeb(url: url))
        XCTAssertFalse(text.hasSourceToWeb(url: URL(string: "https://beamapp.co")!))
    }
}
