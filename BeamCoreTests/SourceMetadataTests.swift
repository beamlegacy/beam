//
//  SourceMetadataTests.swift
//  BeamCoreTests
//
//  Created by Stef Kors on 25/11/2021.
//

import XCTest
import Foundation
@testable import BeamCore

class SourceMetadataTests: XCTestCase {
    var text: BeamText!

    override func setUpWithError() throws {
        self.text = BeamText(text: "text hop bleh")
    }

    func testInitSourceMetadata() throws {
        let title = "Original Note Title"
        let uuid = UUID()

        let source = SourceMetadata(origin: .local(uuid), title: title)
        XCTAssertEqual(source.origin, .local(uuid))
        XCTAssertEqual(source.title, title)
    }

    func testInitWebSourceFromString() throws {
        let urlString = "https://en.wikipedia.org/wiki/Lama_(genus)"

        let source = SourceMetadata(string: urlString)
        XCTAssertEqual(source.origin, .remote(URL(string: "https://en.wikipedia.org/wiki/Lama_(genus)")!))
    }

    func testInitNoteSourceFromString() throws {
        let uuid = UUID()

        let source = SourceMetadata(string: uuid.uuidString)
        XCTAssertEqual(source.origin, .local(uuid))
    }
}
