//
//  BeamElementJoinTests.swift
//  BeamCoreTests
//
//  Created by Stef Kors on 02/09/2021.
//

import Foundation
import XCTest
import Quick
import Nimble

@testable import BeamCore

class BeamElementJoinTests: XCTestCase {
    var parentElement: BeamElement = BeamElement()

    override func setUpWithError() throws {
        self.parentElement = BeamElement()
    }

    func testCanAssignChildrenDirectly() throws {
        parentElement.children = [BeamElement(), BeamElement()]
        XCTAssertEqual(parentElement.children.count, 2)
        for child in parentElement.children {
            XCTAssertNil(child.parent)
        }
    }

    func testCanAddChildrenCorrectly() throws {
        parentElement.addChild(BeamElement())
        parentElement.addChild(BeamElement())
        XCTAssertEqual(parentElement.children.count, 2)
        for child in parentElement.children {
            XCTAssertEqual(child.parent, parentElement)
        }
    }

    func testCanAddChildrenOfBeamText() throws {
        let paragraph1 = BeamElement(BeamText(text: "lorem ipsum..."))
        let paragraph2 = BeamElement(BeamText(text: " dolor met..."))
        parentElement.addChild(paragraph1)
        parentElement.addChild(paragraph2)
        XCTAssertEqual(parentElement.children.count, 2)
    }

    func testCanJoinSimpleChildrenIntoOneBeamText() throws {
        let paragraph1 = BeamElement(BeamText(text: "lorem ipsum..."))
        let paragraph2 = BeamElement(BeamText(text: " dolor met..."))
        parentElement.addChild(paragraph1)
        parentElement.addChild(paragraph2)
        let beamText: BeamText = parentElement.joinTexts
        XCTAssertEqual(beamText.text, "lorem ipsum... dolor met...")
        XCTAssertEqual(beamText.ranges.count, 1)
    }

    func testCanJoinDifferentChildrenIntoOneBeamText() throws {
        let paragraph1 = BeamElement(BeamText(text: "wikipedia", attributes: [.link("https://wikipedia.org")]))
        let paragraph2 = BeamElement(BeamText(text: " dolor met..."))
        parentElement.addChild(paragraph1)
        parentElement.addChild(paragraph2)
        let beamText: BeamText = parentElement.joinTexts
        XCTAssertEqual(beamText.text, "wikipedia dolor met...")
        XCTAssertEqual(beamText.ranges.count, 2)
    }

    func testCanJoinKinds_textJoinsIntoParagraphs() throws {
        let paragraph1 = BeamElement(BeamText(text: "wikipedia"))
        let paragraph2 = BeamElement(BeamText(text: " dolor"))
        let paragraph3 = BeamElement(BeamText(text: " met"))
        let paragraph4 = BeamElement(BeamText(text: "..."))
        parentElement.addChild(paragraph1)
        parentElement.addChild(paragraph2)
        parentElement.addChild(paragraph3)
        parentElement.addChild(paragraph4)
        XCTAssertEqual(parentElement.children.count, 4)

        parentElement.joinKinds()
        XCTAssertEqual(parentElement.children.count, 1)
        if let firstChild = parentElement.children.first {
            XCTAssertEqual(firstChild.text.text, "wikipedia dolor met...")
            XCTAssertEqual(firstChild.text.ranges.count, 1)
        } else {
            XCTFail("expected first child")
        }
    }

    func testCanJoinKinds_textJoinsIntoParagraphsWithLinkRanges() throws {
        let paragraph1 = BeamElement(BeamText(text: "wikipedia", attributes: [.link("https://wikipedia.org")]))
        let paragraph2 = BeamElement(BeamText(text: " dolor"))
        let paragraph3 = BeamElement(BeamText(text: " met"))
        let paragraph4 = BeamElement(BeamText(text: "..."))
        parentElement.addChild(paragraph1)
        parentElement.addChild(paragraph2)
        parentElement.addChild(paragraph3)
        parentElement.addChild(paragraph4)
        XCTAssertEqual(parentElement.children.count, 4)

        let element: BeamElement = parentElement.joinKinds()

        XCTAssertEqual(element.children.count, 1)
        if let firstChild = parentElement.children.first {
            XCTAssertEqual(firstChild.text.text, "wikipedia dolor met...")
            XCTAssertEqual(firstChild.text.ranges.count, 2)
        } else {
            XCTFail("expected first child")
        }
    }

    func testCanJoinKinds_imagesSplitParagraphs() throws {
        let paragraph1 = BeamElement(BeamText(text: "wikipedia", attributes: [.link("https://wikipedia.org")]))
        let paragraph2 = BeamElement(BeamText(text: " dolor"))
        let image1 = BeamElement(BeamText(text: "google logo"))
        image1.kind = .image(SourceMetadata(origin: .local(UUID())), displayInfos: MediaDisplayInfos())
        let paragraph3 = BeamElement(BeamText(text: " met"))
        let paragraph4 = BeamElement(BeamText(text: "..."))
        parentElement.addChild(paragraph1)
        parentElement.addChild(paragraph2)
        parentElement.addChild(image1)
        parentElement.addChild(paragraph3)
        parentElement.addChild(paragraph4)
        XCTAssertEqual(parentElement.children.count, 5)

        let element: BeamElement = parentElement.joinKinds()
        XCTAssertEqual(element.children.count, 3)

        // Assert first child (joined paragraph with link)
        if let firstChild = parentElement.children.first {
            XCTAssertEqual(firstChild.text.text, "wikipedia dolor")
            XCTAssertEqual(firstChild.text.ranges.count, 2)
        } else {
            XCTFail("expected first child")
        }

        // Assert second child (image)
        let imageChild = parentElement.children[1]
        XCTAssertEqual(imageChild.text.text, "google logo")
        XCTAssertEqual(imageChild.kind, image1.kind)
        XCTAssertEqual(imageChild.text.ranges.count, 1)

        // Assert last child (second joined paragraph)
        if let lastChild = parentElement.children.last {
            XCTAssertEqual(lastChild.text.text, " met...")
            XCTAssertEqual(lastChild.text.ranges.count, 1)
        } else {
            XCTFail("expected last child")
        }
    }
}
