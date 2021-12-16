//
//  TextLineTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 28/04/2021.
//

import Foundation
import XCTest
import Nimble

@testable import BeamCore
@testable import Beam

class TextFrameTests: XCTestCase {

    var attributedString = NSMutableAttributedString()
    var actualString = ""
    var carets = [Caret]()
    var cursor = 0

    private func checkCaret(_ cursor: Int, _ expectedCursor: Int, _ indexInSource: Int, _ edge: CaretEdge, _ inSource: Bool, _ textOnScreen: String, _ textInSource: String) {
        let caret = carets[cursor]
        expect(cursor) == expectedCursor
        expect(caret.indexInSource) == indexInSource
        expect(caret.edge) == edge
        expect(caret.inSource) == inSource
        expect(String(self.attributedString.string.prefix(caret.positionOnScreen))) == textOnScreen
        expect(String(self.actualString.prefix(caret.positionInSource))) == textInSource
    }

    private func dumpCarets() -> String {
        var index = 0
        return carets.reduce(String()) { value, caret -> String in
            defer { index += 1 }
            let s1 = String(actualString.prefix(caret.positionInSource))
            let s2 = String(attributedString.string.prefix(caret.positionOnScreen))

            return value + "[\(index)]\(caret.debugDescription) - '\(s1)' / '\(s2)'\n"
        }
    }

    // swiftlint:disable:next function_body_length
    func testLinkLayoutForOneLine() {
        let fontSize = CGFloat(12)
        let elementKind = ElementKind.bullet
        let textWidth = CGFloat(400)

        var text = BeamText(text: "1")
        expect(text.links.count) == 0
        let position1 = text.count
        text.append(BeamText(text: "2", attributes: [.link("http://somelink.com")]))
        let position2 = text.count
        text.append(BeamText(text: "3"))
        //let position3 = text.count
        actualString = text.text
        expect(text.links.count) == 1

        let config = BeamTextAttributedStringBuilder.Config(elementKind: elementKind,
                                                            ranges: text.ranges,
                                                            fontSize: fontSize, fontColor: .white,
                                                            searchedRanges: [])
        let asBuilder = BeamTextAttributedStringBuilder()
        attributedString = asBuilder.build(config: config)
        let position = NSPoint(x: 0, y: 0)

        let textFrame = TextFrame.create(string: attributedString, atPosition: position, textWidth: textWidth, singleLineHeightFactor: nil, maxHeight: nil)
        carets = textFrame.carets

        expect(textFrame.frame.origin) == position
        XCTAssertLessThanOrEqual(textFrame.frame.width, textWidth + 3)
        expect(textFrame.frame.height).to(beCloseTo(15, within: 0.1))
        expect(textFrame.lines.count) == 1

        expect(textFrame.carets.count) == actualString.count * 2 + 2 // * 2 because two edges per character, + 2 because the link add the virtual image character

        expect(textFrame.caretIndexForSourcePosition(0)) == 0
        expect(textFrame.caretIndexForSourcePosition(1)) == 2
        expect(textFrame.caretIndexForSourcePosition(position1)) == position1 * 2
        expect(textFrame.caretIndexForSourcePosition(position2)) == position2 * 2
        expect(textFrame.caretIndexForSourcePosition(position2 + 1)) == (position2 + 1) * 2 + 1

        //swiftlint:disable:next print
//        print("Carets:\n\(dumpCarets())")

        // Check all carets:
        checkCaret(0, 0, 0, .leading, true, "", "")
        checkCaret(1, 1, 0, .trailing, true, "1", "1")
        checkCaret(2, 2, 1, .leading, true, "1", "1")
        checkCaret(3, 3, 1, .trailing, true, "12", "12")
        checkCaret(4, 4, 2, .leading, false, "12", "12")
        checkCaret(5, 5, 2, .trailing, false, "12 ", "12")
        checkCaret(6, 6, 2, .leading, true, "12 ", "12")
        checkCaret(7, 7, 2, .trailing, true, "12 3", "123")

        // Now test cursor movements:
        cursor = 0
        checkCaret(cursor, 0, 0, .leading, true, "", "")

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 2

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 4

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 6

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 7

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 7

        //////////////////////////////////////////////////////
        // Now go back:
        //////////////////////////////////////////////////////
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

    // swiftlint:disable:next function_body_length
    func testLinkLayoutForOneMultipleLines() {
        let fontSize = CGFloat(12)
        let elementKind = ElementKind.bullet
        let textWidth = CGFloat(20)

        var text = BeamText(text: "1 ")
        expect(text.links.count) == 0
        let position1 = text.count
        text.append(BeamText(text: "2", attributes: [.link("http://somelink.com")]))
        let position2 = text.count
        text.append(BeamText(text: " 3"))
        //let position3 = text.count
        actualString = text.text
        expect(text.links.count) == 1

        let config = BeamTextAttributedStringBuilder.Config(elementKind: elementKind,
                                                            ranges: text.ranges,
                                                            fontSize: fontSize, fontColor: .white,
                                                            searchedRanges: [])
        let asBuilder = BeamTextAttributedStringBuilder()
        attributedString = asBuilder.build(config: config)

        let position = NSPoint(x: 0, y: 0)

        let textFrame = TextFrame.create(string: attributedString, atPosition: position, textWidth: textWidth, singleLineHeightFactor: nil, maxHeight: nil)
        carets = textFrame.carets

        expect(textFrame.frame.origin) == position
        expect(textFrame.frame.width) <= 30
        expect(textFrame.frame.height).to(beCloseTo(30, within: 0.1))
        expect(textFrame.lines.count) == 2

        expect(textFrame.carets.count) == actualString.count * 2 + 2 // * 2 because two edges per character, + 2 because the link add the virtual image character

        //swiftlint:disable:next print
//        print("Carets:\n\(dumpCarets())")
        expect(textFrame.caretIndexForSourcePosition(0)) == 0
        expect(textFrame.caretIndexForSourcePosition(1)) == 2
        expect(textFrame.caretIndexForSourcePosition(position1)) == position1 * 2
        expect(textFrame.caretIndexForSourcePosition(position2)) == position2 * 2
        expect(textFrame.caretIndexForSourcePosition(position2 + 1)) == (position2 + 1) * 2 + 2 // add 2 because of the link that add 1 char (1 char = 2 carets)

        // Now test cursor movements:
        cursor = 0

        // Check all carets:
        checkCaret(0, 0, 0, .leading, true, "", "")
        checkCaret(1, 1, 0, .trailing, true, "1", "1")
        checkCaret(2, 2, 1, .leading, true, "1", "1")
        checkCaret(3, 3, 1, .trailing, true, "1 ", "1 ")
        checkCaret(4, 4, 2, .leading, true, "1 ", "1 ")
        checkCaret(5, 5, 2, .trailing, true, "1 2", "1 2")
        checkCaret(6, 6, 3, .leading, false, "1 2", "1 2")
        checkCaret(7, 7, 3, .trailing, false, "1 2 ", "1 2")
        checkCaret(8, 8, 3, .leading, true, "1 2 ", "1 2")
        checkCaret(9, 9, 3, .trailing, true, "1 2  ", "1 2 ")
        checkCaret(10, 10, 4, .leading, true, "1 2  ", "1 2 ")
        checkCaret(11, 11, 4, .trailing, true, "1 2  3", "1 2 3")

        expect(self.cursor) == 0

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 2

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 4

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 6

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 8

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 9

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 10

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 11

        cursor = nextCaret(for: cursor, in: carets)
        expect(self.cursor) == 11

        //////////////////////////////////////////////////////
        // Now go back:
        //////////////////////////////////////////////////////
        expect(self.cursor) == 11

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 10

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 9

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 8

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 6

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 4

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 2

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 0

        cursor = previousCaret(for: cursor, in: carets)
        expect(self.cursor) == 0
    }
}
