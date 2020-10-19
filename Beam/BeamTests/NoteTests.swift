import Foundation
import Fakery

import XCTest
@testable import Beam

class NoteTests: CoreDataTests {
    let faker = Faker(locale: "en-US")

    func testNoteCreation() throws {
        let title = faker.lorem.words()

        let oldCount = Note.countWithPredicate(context)

        let note = Note.createNote(context, title)

        XCTAssertNotNil(note)

        XCTAssertNoThrow(try context.save())

        let newCount = Note.countWithPredicate(context)
        XCTAssertEqual(newCount, oldCount + 1)
    }

    func testNoteWithBulletsCreation() throws {
        let title = faker.lorem.words()
        let note = Note.createNote(context, title)

        let bullet1 = note.createBullet(context, content: "bullet 1")

        XCTAssertNotNil(bullet1)
        XCTAssertEqual(bullet1.orderIndex, 1)

        let bullet2 = note.createBullet(context, content: "bullet 2")
        XCTAssertEqual(bullet2.orderIndex, 2)

        let bullet3 = note.createBullet(context, content: "bullet 3")
        XCTAssertEqual(bullet3.orderIndex, 3)

        XCTAssertEqual(note.sortedBullets(context), [bullet1, bullet2, bullet3])

        let bullet4 = note.createBullet(context, content: "bullet 4", afterBullet: bullet1)
        XCTAssertEqual(bullet4.orderIndex, 2)

        XCTAssertEqual(note.sortedBullets(context), [bullet1, bullet4, bullet2, bullet3])

        let bullet5 = note.createBullet(context, content: "bullet 5", afterBullet: bullet1)
        XCTAssertEqual(bullet5.orderIndex, 2)

        XCTAssertEqual(bullet1.orderIndex, 1)
        XCTAssertEqual(bullet4.orderIndex, 3)
        XCTAssertEqual(bullet2.orderIndex, 4)
        XCTAssertEqual(bullet3.orderIndex, 5)

        XCTAssertEqual(note.sortedBullets(context), [bullet1, bullet5, bullet4, bullet2, bullet3])
    }

    func testNoteWithBulletsAndChildrenCreation() throws {
        let title = faker.lorem.words()
        let note = Note.createNote(context, title)

        let bullet1 = note.createBullet(context, content: "bullet 1")

        XCTAssertNotNil(bullet1)
        XCTAssertEqual(bullet1.orderIndex, 1)

        let bullet2 = note.createBullet(context, content: "bullet 2")
        XCTAssertEqual(bullet2.orderIndex, 2)

        XCTAssertEqual(note.sortedBullets(context), [bullet1, bullet2])

        let bullet11 = note.createBullet(context, content: "bullet 11", parentBullet: bullet1)
        _ = note.createBullet(context, content: "bullet 12", afterBullet: bullet11)

        let bullet111 = note.createBullet(context, content: "bullet 111", parentBullet: bullet11)
        let bullet112 = note.createBullet(context, content: "bullet 112", afterBullet: bullet111)
        _ = note.createBullet(context, content: "bullet 113", afterBullet: bullet111)
        _ = note.createBullet(context, content: "bullet 114", afterBullet: bullet112)

        note.debugNote()
        XCTAssertEqual(bullet11.orderIndex, 1)
    }

    func testNoteFetch() throws {
        let countBefore = Note.countWithPredicate(context)
        XCTAssertEqual(countBefore, 0)

        let count = 10

        for _ in 1...count {
            let title = faker.lorem.words()
            Note.createNote(context, title)
        }

        let countAfter = Note.countWithPredicate(context)

        XCTAssertEqual(countAfter, countBefore + count)
    }

    func testNoteFetchWithTitle() throws {
        Note.createNote(context, "foobar 1")
        Note.createNote(context, "foobar 2")
        Note.createNote(context, "foobar 3")
        Note.createNote(context, "another title")

        XCTAssertEqual(Note.fetchAllWithTitleMatch(context, "foobar").count, 3)
    }

    func testNoteTitleLinkReplacements() throws {
        let newNote = Note.createNote(context, "[[foobar]] and [[another card]] and #another")

        XCTAssertEqual(newNote.parsedTitle(), "[[[foobar](beam://beamapp.co/note?title=foobar)]] and [[[another card](beam://beamapp.co/note?title=another%20card)]] and #[another](beam://beamapp.co/note?title=another)")
    }

    func testNoteFetchFirst() throws {
        let note = Note.createNote(context, "foobar 1")

        XCTAssertEqual(Note.fetchFirst(context: context), note)
    }

    func testPerformanceFetch() throws {
        let title = faker.lorem.words()
        var ids: [UUID] = []
        let count = 100

        for _ in 1...count {
            let note = Note.createNote(context, title)

            ids.append(note.id)
        }

        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(ids.count, count)

        self.measure {
            if let randomId = ids.randomElement() {
                let note = Note.fetchWithId(context, randomId)

                XCTAssertNotNil( note )
                XCTAssertEqual(note?.title, title)
                XCTAssertEqual(note?.id, randomId)
            }
        }
    }

    func testPerformanceInsert() throws {
        let title = faker.lorem.words()
        let count = 100
        var ids: [UUID] = []

        self.measure {
            for _ in 1...count {
                let note = Note.createNote(context, title)

                ids.append(note.id)
            }

            do {
                try context.save()
            } catch { }
        }
    }
}
