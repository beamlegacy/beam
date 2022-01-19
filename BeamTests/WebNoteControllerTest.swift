import XCTest

@testable import Beam
@testable import BeamCore

class WebNoteControllerTest: XCTestCase {

    func testCreateFromNote() throws {
        let note = BeamNote(title: "Sample note")

        let controller = WebNoteController(note: note)

        XCTAssertEqual(controller.note, note)
        XCTAssertEqual(controller.rootElement, note)
        XCTAssertEqual(controller.element, note)
    }

    func testCreateFromElement() throws {
        let note = BeamNote(title: "Sample note")
        let child1 = BeamElement("child 1")
        note.addChild(child1)
        let child2 = BeamElement("child 2")
        note.addChild(child2)
        let root = note.children[1]

        let controller = WebNoteController(note: note, rootElement: root)

        XCTAssertEqual(controller.note, note)
        XCTAssertEqual(controller.rootElement, root)
        XCTAssertTrue(note != root)
        let element = controller.element
        XCTAssertNotEqual(element, note)
        XCTAssertEqual(element, root)
    }

}
