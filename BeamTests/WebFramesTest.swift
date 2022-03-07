//
//  WebFramesTest.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 22/02/2022.
//

import XCTest

import Combine
@testable import Beam
@testable import BeamCore

class WebFramesTest: XCTestCase {
    var webFrames = WebFrames()
    var cancellables = Set<AnyCancellable>()
    var removedFrames = Set<String>()

    override func setUpWithError() throws {
        webFrames.removedFrames.sink { href in
            self.removedFrames.insert(href)
        }
        .store(in: &cancellables)
        setFrame(isMain: true, href: "https://www.webpage.com", children: "https://www.iframe1.com", "https://www.iframe2.com")
        setFrame(href: "https://www.iframe1.com", children: "https://www.iframe11.com", "https://www.iframe12.com")
        setFrame(href: "https://www.iframe2.com", children: "https://www.iframe21.com", "https://www.iframe22.com")
        setFrame(href: "https://www.iframe11.com")
        setFrame(href: "https://www.iframe12.com")
        setFrame(href: "https://www.iframe21.com")
        setFrame(href: "https://www.iframe22.com")
        XCTAssertEqual(self.webFrames.frames.count, 7)
        XCTAssertEqual(removedFrames.count, 0)
    }

    func testChildMutation() throws {
        setFrame(href: "https://www.iframe1.com", children: "https://www.iframe13.com", "https://www.iframe14.com")
        setFrame(href: "https://www.iframe13.com")
        setFrame(href: "https://www.iframe14.com")
        XCTAssertEqual(self.webFrames.frames.count, 7)
        XCTAssertEqual(removedFrames.count, 2)
        XCTAssert(removedFrames.contains("https://www.iframe11.com"))
        XCTAssert(removedFrames.contains("https://www.iframe12.com"))
    }

    func testRootMutation() {
        setFrame(isMain: true, href: "https://www.webpage.com", children: "https://www.iframe3.com")
        setFrame(href: "https://www.iframe3.com")
        XCTAssertEqual(self.webFrames.frames.count, 2)
        XCTAssertEqual(removedFrames.count, 6)
        XCTAssert(removedFrames.contains("https://www.iframe1.com"))
        XCTAssert(removedFrames.contains("https://www.iframe2.com"))
        XCTAssert(removedFrames.contains("https://www.iframe11.com"))
        XCTAssert(removedFrames.contains("https://www.iframe12.com"))
        XCTAssert(removedFrames.contains("https://www.iframe21.com"))
        XCTAssert(removedFrames.contains("https://www.iframe22.com"))
    }

    private func setFrame(isMain: Bool = false, href: String, children: String...) {
        webFrames.setFrame(href: href, children: Set(children), isMain: isMain)
    }
}
