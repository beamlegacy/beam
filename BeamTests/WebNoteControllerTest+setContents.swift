//
//  WebNoteControllerTest+setContents.swift
//  BeamTests
//
//  Created by Stef Kors on 23/11/2021.
//

import XCTest

@testable import Beam
@testable import BeamCore

class WebNoteControllerTest_setContents: XCTestCase {
    var simpleTextController: WebNoteController!
    var textLinkController: WebNoteController!
    var textEmphasisController: WebNoteController!
    var complexTextController: WebNoteController!
    var url = URL(string: urlString)!
    static var urlString = "https://www.google.com/search?q=duck&client=safari"

    func createController(child: BeamElement) -> WebNoteController {
        let note = BeamNote(title: "Sample note")
        note.addChild(child)
        let root = note.children[0]
        return WebNoteController(note: note, rootElement: root)
    }

    override func setUpWithError() throws {
        self.simpleTextController = self.createController(child: BeamElement("lama"))
        self.textLinkController = self.createController(child: BeamElement(BeamText(text: "lama", attributes: [.link(url.absoluteString)])))
        self.textEmphasisController = self.createController(child: BeamElement(BeamText(text: "lama", attributes: [.emphasis])))
        self.complexTextController = self.createController(child: BeamElement(BeamText(text: "lama", attributes: [.link(url.absoluteString), .emphasis])))
    }

    /// If an empty title string is provided, we expect the text to update to the url string
    func testTitle_simple_EmptyString() throws {
        let titleFromSiteTitleUpdate = ""
        simpleTextController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(simpleTextController.element.text.text, "lama")
    }

    /// If a full title string is provided, we expect the text to update to that string
    func testTitle_simple_PageTitleString() throws {
        let titleFromSiteTitleUpdate = "lama - Google Search"
        simpleTextController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(simpleTextController.element.text.text, titleFromSiteTitleUpdate)
    }

    /// If nil is provided, we expect the text not to update
    func testTitle_simple_nil() throws {
        let titleFromSiteTitleUpdate: String? = nil
        simpleTextController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(simpleTextController.element.text.text, "lama")
    }

    /// If an empty title string is provided, we expect the text to update to the url string
    func testTitle_textLink_EmptyString() throws {
        let titleFromSiteTitleUpdate = ""
        textLinkController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(textLinkController.element.text.text, "lama")
    }

    /// If a full title string is provided, we expect the text to update to that string
    func testTitle_textLink_PageTitleString() throws {
        let titleFromSiteTitleUpdate = "lama - Google Search"
        textLinkController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(textLinkController.element.text.text, titleFromSiteTitleUpdate)
    }

    /// If nil is provided, we expect the text not to update
    func testTitle_textLink_nil() throws {
        let titleFromSiteTitleUpdate: String? = nil
        textLinkController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(textLinkController.element.text.text, "lama")
    }

    /// If an empty title string is provided, we expect the text to update to the url string
    func testTitle_textEmphasis_EmptyString() throws {
        let titleFromSiteTitleUpdate = ""
        textEmphasisController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(textEmphasisController.element.text.text, "lama")
    }

    /// If a full title string is provided, we expect the text to update to that string
    func testTitle_textEmphasis_PageTitleString() throws {
        let titleFromSiteTitleUpdate = "lama - Google Search"
        textEmphasisController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(textEmphasisController.element.text.text, titleFromSiteTitleUpdate)
    }

    /// If nil is provided, we expect the text not to update
    func testTitle_textEmphasis_nil() throws {
        let titleFromSiteTitleUpdate: String? = nil
        textEmphasisController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(textEmphasisController.element.text.text, "lama")
    }

    // If complex text don't update string
    func testTitle_ComplicatedText_EmptyString() throws {
        let titleFromSiteTitleUpdate = ""
        complexTextController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(complexTextController.element.text.text, "lama")
    }

    // If complex text don't update string
    func testTitle_ComplicatedText_PageTitleString() throws {
        let titleFromSiteTitleUpdate = "lama - Google Search"
        complexTextController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(complexTextController.element.text.text, "lama")
    }

    // If complex text don't update string
    func testTitle_ComplicatedText_nil() throws {
        let titleFromSiteTitleUpdate: String? = nil
        complexTextController.setContents(url: url, text: titleFromSiteTitleUpdate)
        XCTAssertEqual(complexTextController.element.text.text, "lama")
    }
}
