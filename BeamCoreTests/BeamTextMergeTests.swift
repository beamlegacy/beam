import XCTest
@testable import BeamCore

class BeamTextMergeTests: XCTestCase {

    func testSplitBeamText1() throws {
        let text = BeamText(text: "Bonjour le monde.")
        let elements = text.splitForMerge()
        XCTAssertEqual(elements, [BeamText("Bonjour"), BeamText(" "), BeamText("le"), BeamText(" "), BeamText("monde"), BeamText(".")])
    }

    func testSplitBeamText2() throws {
        let text = BeamText(text: "Bonjour  le , monde.")
        let elements = text.splitForMerge()
        XCTAssertEqual(elements, [BeamText("Bonjour"), BeamText(" "), BeamText(" "), BeamText("le"), BeamText(" "), BeamText(","), BeamText(" "), BeamText("monde"), BeamText(".")])
    }

    func testMergeBeamText1() {
        let ancestor = BeamText("Bonjour le monde")
        let mine = BeamText("Bonjour les monde")
        let theirs = BeamText("Bonjour le mondes")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs), BeamText("Bonjour les mondes"))
    }

    func testMergeBeamText2() {
        let ancestor = BeamText("Bonjour le monde")
        let mine = BeamText("Bonjour le monde")
        let theirs = BeamText("Bonjour le monde")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs), BeamText("Bonjour le monde"))
    }

    func testMergeBeamText3() {
        let ancestor = BeamText("Bonjour")
        let mine = BeamText("Bonjour le")
        let theirs = BeamText("Bonjour le monde")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs), BeamText("Bonjour le monde"))
    }

    func testMergeBeamText4() {
        let ancestor = BeamText("Bonjour mec")
        let mine = BeamText("Bonjour le")
        let theirs = BeamText("Bonjour le monde")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs), BeamText("Bonjour le monde"))
    }

    func testMergeBeamText5() {
        let ancestor = BeamText("Bonjour mec")
        let mine = BeamText("Bonjour le monde")
        let theirs = BeamText("Salut le monde")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs), BeamText("Salut le monde"))
    }

    func testMergeBeamText6() {
        let ancestor = BeamText("Bonjour mec")
        let mine = BeamText("Hello le monde")
        let theirs = BeamText("Salut le monde")
        XCTAssertNil(mine.merge(ancestor: ancestor, other: theirs))
    }

    func testMergeBeamText7() {
        let ancestor = BeamText("Bonjour mec")
        let mine = BeamText("Hello le monde")
        let theirs = BeamText("Salut le monde")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs, strategy: .chooseMine), BeamText("Hello le monde"))
    }

    func testMergeBeamText8() {
        let ancestor = BeamText("Bonjour mec")
        let mine = BeamText("Hello le monde")
        let theirs = BeamText("Salut le monde")
        XCTAssertEqual(mine.merge(ancestor: ancestor, other: theirs, strategy: .chooseTheirs), BeamText("Salut le monde"))
    }
}
