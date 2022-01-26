//
//  HtmlVisitorTests.swift
//  BeamTests
//
//  Created by Stef Kors on 17/09/2021.
//

import  Nimble
import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class HtmlVisitorTests: XCTestCase {
    let testFileStorage: BeamFileStorage? = nil
    let testDownloadManager: BeamDownloadManager? = nil

    override func setUp() {
        super.setUp()
    }

    func testGetBase64_EmptyString() throws {
        let src = ""
        let url = URL(string: "https://www.kanye.com")!
        let visitor = HtmlVisitor(url, testDownloadManager, testFileStorage)
        let results = visitor.getBase64(src)
        XCTAssertNil(results)
    }

    func testGetBase64_dataImagePNG() throws {
        let src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="

        let url = URL(string: "https://www.kanye.com")!
        let visitor = HtmlVisitor(url, testDownloadManager, testFileStorage)
        if let (base64, mimeType) = visitor.getBase64(src),
           let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==") {
            XCTAssertEqual(base64, data)
            XCTAssertEqual(mimeType, "image/png;base64")
        } else {
            XCTFail("expected getBase64 to return tuple, received nil")
        }
    }


}
