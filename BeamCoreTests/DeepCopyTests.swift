//
//  DeepCopyTests.swift
//  BeamCoreTests
//
//  Created by Jean-Louis Darmon on 23/06/2021.
//

import XCTest
import Nimble
@testable import BeamCore

class DeepCopyTests: XCTestCase {

    private func setupTree() -> BeamNote {
        let note = BeamNote.init(title: "DeepCopytest")

        let bullet1 = BeamElement("First bullet")
        note.addChild(bullet1)
        let bullet2 = BeamElement("Second bullet")
        note.addChild(bullet2)
        let bullet3 = BeamElement("Third bullet")
        note.addChild(bullet3)
        return note
    }

    private func checkChildrenId(originalChildren: [BeamElement], duplicatedChidren: [BeamElement], withNewId: Bool) {
        for originalChild in originalChildren {
            guard let index = originalChildren.firstIndex(of: originalChild) else { continue }
            if withNewId {
                expect(originalChild.id).toNot(equal(duplicatedChidren[index].id))
            } else {
                expect(originalChild.id).to(equal(duplicatedChidren[index].id))
            }
            expect(originalChild.text).to(equal(duplicatedChidren[index].text))
        }
    }

    func testDeepCopy() {
        let note = setupTree()
        guard let noteDuplicated = note.deepCopy(withNewId: false, selectedElements: nil) else { return }
        expect(note).to(equal(noteDuplicated))
        expect(note.id).to(equal(noteDuplicated.id))
        expect(note.children.count).to(equal(noteDuplicated.children.count))
        checkChildrenId(originalChildren: note.children, duplicatedChidren: noteDuplicated.children, withNewId: false)
    }

    func testDeepCopyWithNewId() {
        let note = setupTree()
        guard let noteDuplicated = note.deepCopy(withNewId: true, selectedElements: nil) else { return }
        expect(note).toNot(equal(noteDuplicated))
        expect(note.id).toNot(equal(noteDuplicated.id))
        expect(note.children.count).to(equal(noteDuplicated.children.count))
        checkChildrenId(originalChildren: note.children, duplicatedChidren: noteDuplicated.children, withNewId: true)
    }

    func testDeepCopyWithNewIdAndSelection() {
        let note = setupTree()
        guard let firstChild = note.children.first,
              let lastChild = note.children.last else { return }
        let selectedElements = [firstChild, lastChild]
        guard let noteDuplicated = note.deepCopy(withNewId: true, selectedElements: selectedElements) else { return }
        expect(note).toNot(equal(noteDuplicated))
        expect(note.id).toNot(equal(noteDuplicated.id))
        expect(note.children.count).toNot(equal(noteDuplicated.children.count))
        expect(noteDuplicated.children.count).to(equal(selectedElements.count))
        checkChildrenId(originalChildren: selectedElements, duplicatedChidren: noteDuplicated.children, withNewId: true)
        for duplicatedChild in noteDuplicated.children {
            note.insert(duplicatedChild, after: note.children.last)
        }
        expect(note.children.count).to(equal(5))
    }
}
