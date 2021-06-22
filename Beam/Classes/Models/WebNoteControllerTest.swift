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

    func testAdd() throws {
        let note = BeamNote(title: "Sample note")

        let controller = WebNoteController(note: note)

        let someTitle = "Some website"
        let someUrl = "https://www.website.com"
        let added = controller.add(url: URL(string: someUrl)!, text: someTitle, isNavigation: true)
        let noteChildren = controller.note.children
        XCTAssertEqual(noteChildren.count, 1)
        XCTAssertEqual(noteChildren[0], added)
        XCTAssertEqual(controller.element, added)
        let addedText = added.text
        XCTAssertEqual(addedText.text, someTitle)
        let attribute = addedText.ranges[0].attributes[0]
        XCTAssertEqual(attribute, .link(someUrl))

        // Add the same
        let addedAgain = controller.add(url: URL(string: someUrl)!, text: someTitle, isNavigation: true)
        XCTAssertEqual(note.children.count, 1)   // Still one, no add
        XCTAssertEqual(controller.element, added)
        XCTAssertEqual(addedAgain, added)

        // Navigation doesn't nest
        let subAdd = controller.add(url: URL(string: "http://some.linked.website")!, text: "Some linked website", isNavigation: true)
        XCTAssertEqual(note.children.count, 2)   // New bullet, not nested
        XCTAssertEqual(controller.element, subAdd)
        XCTAssertEqual(note.children[1], subAdd)

        // Direct access doesn't nest
        let parallelAdd = controller.add(url: URL(string: "http://some.other")!, text: "Some parallel website", isNavigation: false)
        XCTAssertEqual(note.children.count, 3)   // Still one, other is nested
        XCTAssertEqual(note.children[2], parallelAdd)
    }
}
