//
//  TextLineTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 28/04/2021.
//

import Foundation
import XCTest

@testable import BeamCore
@testable import Beam

class TextFrameTests: XCTestCase {

    // swiftlint:disable:next function_body_length
    func testLinkLayout() {
        let fontSize = CGFloat(12)
        let cursorPosition = 10
        let elementKind = ElementKind.bullet
        let mouseInteraction = MouseInteraction(type: .unknown, range: NSRange())
        let textWidth = CGFloat(400)

        var text = BeamText(text: "1")
        XCTAssertEqual(text.links.count, 0)
        let position1 = text.count
        text.append(BeamText(text: "2", attributes: [.link("http://somelink.com")]))
        let position2 = text.count
        text.append(BeamText(text: "3"))
        let position3 = text.count
        let actualString = text.text
        XCTAssertEqual(text.links.count, 1)


        let attributedString = text.buildAttributedString(fontSize: fontSize, cursorPosition: cursorPosition, elementKind: elementKind, mouseInteraction: mouseInteraction)
        let position = NSPoint(x: 0, y: 0)

        let textFrame = TextFrame.create(string: attributedString, atPosition: position, textWidth: textWidth)

        XCTAssertEqual(textFrame.frame.origin, position)
        XCTAssertLessThanOrEqual(textFrame.frame.width, textWidth + 3)
        XCTAssertEqual(textFrame.frame.height, 14.5, accuracy: 0.1)
        XCTAssertEqual(textFrame.lines.count, 1)

        XCTAssertEqual(textFrame.carets.count, actualString.count * 2 + 2) // * 2 because two edges per character, + 2 because the link add the virtual image character

        XCTAssertEqual(textFrame.caretIndexForSourcePosition(0), 0)
        XCTAssertEqual(textFrame.caretIndexForSourcePosition(1), 2)
        XCTAssertEqual(textFrame.caretIndexForSourcePosition(position1), position1 * 2)
        XCTAssertEqual(textFrame.caretIndexForSourcePosition(position2), position2 * 2)
        XCTAssertEqual(textFrame.caretIndexForSourcePosition(position2 + 1), (position2 + 1) * 2 + 1)

        // Now test cursor movements:
        var cursor = 0
        let carets = textFrame.carets

        let checkCaret: (Int, Int, Int, CaretEdge, Bool, String, String) -> Void = { cursor, _cursor, indexInSource, edge, inSource, textOnScreen, textInSource in
            let caret = carets[cursor]
            XCTAssertEqual(cursor, _cursor)
            XCTAssertEqual(caret.indexInSource, indexInSource)
            XCTAssertEqual(caret.edge, edge)
            XCTAssertEqual(caret.inSource, inSource)
            XCTAssertEqual(String(attributedString.string.prefix(caret.positionOnScreen)), textOnScreen)
            XCTAssertEqual(String(actualString.prefix(caret.positionInSource)), textInSource)
        }

        // Check all carets:
        checkCaret(0, 0, 0, .leading, true, "", "")
        checkCaret(1, 1, 0, .trailing, true, "1", "1")
        checkCaret(2, 2, 1, .leading, true, "1", "1")
        checkCaret(3, 3, 1, .trailing, true, "12", "12")
        checkCaret(4, 4, 2, .leading, false, "12", "12")
        checkCaret(5, 5, 2, .trailing, false, "12 ", "12")
        checkCaret(6, 6, 2, .leading, true, "12 ", "12")
        checkCaret(7, 7, 2, .trailing, true, "12 3", "123")

        checkCaret(cursor, 0, 0, .leading, true, "", "")

        cursor = nextCaret(for: cursor, in: carets)
        checkCaret(cursor, 2, 1, .leading, true, "1", "1")

        cursor = nextCaret(for: cursor, in: carets)
        checkCaret(cursor, 4, 2, .leading, false, "12", "12")

        cursor = nextCaret(for: cursor, in: carets)
        checkCaret(cursor, 6, 2, .leading, true, "12 ", "12")

        cursor = nextCaret(for: cursor, in: carets)
        checkCaret(cursor, 7, 2, .trailing, true, "12 3", "123")

        cursor = nextCaret(for: cursor, in: carets)
        checkCaret(cursor, 7, 2, .trailing, true, "12 3", "123")

        //////////////////////////////////////////////////////
        // Now go back:
        //////////////////////////////////////////////////////
        cursor = 7
        checkCaret(cursor, 7, 2, .trailing, true, "12 3", "123")

        cursor = previousCaret(for: cursor, in: carets)
        checkCaret(cursor, 6, 2, .leading, true, "12 ", "12")

        cursor = previousCaret(for: cursor, in: carets)
        checkCaret(cursor, 4, 2, .leading, false, "12", "12")

        cursor = previousCaret(for: cursor, in: carets)
        checkCaret(cursor, 2, 1, .leading, true, "1", "1")

        cursor = previousCaret(for: cursor, in: carets)
        checkCaret(cursor, 0, 0, .leading, true, "", "")

        cursor = previousCaret(for: cursor, in: carets)
        checkCaret(cursor, 0, 0, .leading, true, "", "")
    }
}

