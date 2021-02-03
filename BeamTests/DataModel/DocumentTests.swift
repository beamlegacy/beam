import Foundation
import Fakery
import XCTest
import Nimble

@testable import Beam

class DocumentTests: CoreDataTests {
    let faker = Faker(locale: "en-US")

    override func tearDown() {
        BeamDate.reset()
    }

    func testDocumentFetch() throws {
        let countBefore = Document.countWithPredicate(context)
        expect(countBefore).to(equal(0))

        let count = 3

        for _ in 1...count {
            _ = Document.create(context, title: faker.lorem.words())
        }

        let countAfter = Document.countWithPredicate(context)
        expect(countAfter).to(equal(countBefore + count))
    }

    func testDocumentUpdatedAt() throws {
        let document = Document.create(context, title: "foobar 1")
        expect(document.updated_at).toNot(beNil())

        BeamDate.travel(0.5)
        let initialUpdatedAt = document.updated_at
        document.title = "foobar 2"
        try? context.save()
        expect(document.updated_at).to(equal(initialUpdatedAt))

        BeamDate.travel(1.5)
        document.title = "foobar 3"
        try? context.save()
        expect(document.updated_at).toNot(equal(initialUpdatedAt))
        expect(document.updated_at).to(beGreaterThan(initialUpdatedAt))
        expect(document.updated_at.timeIntervalSince(initialUpdatedAt)).to(beGreaterThan(2.0))
    }

    func testDocumentFetchWithTitle() throws {
        _ = Document.create(context, title: "foobar 1")
        _ = Document.create(context, title: "foobar 2")
        _ = Document.create(context, title: "foobar 3")
        _ = Document.create(context, title: "another title")

        expect(Document.fetchAllWithTitleMatch(self.context, "foobar")).to(haveCount(3))
    }

    func testMD5() throws {
        let document = Document.create(context, title: "foobar")
        document.data = "foobar".data(using: .utf8)
        // Calculated from Ruby with Digest::MD5.hexdigest "foobar"
        expect(document.data?.MD5).to(equal("3858f62230ac3c915f300c664312c63f"))
    }

    func testDuplicateIds() throws {
        let id = UUID()
        let title = faker.zelda.game()

        let document1 = Document.create(context, title: title)
        let document2 = Document.create(context, title: title)

        document1.id = id
        document2.id = id

        expect { try CoreDataManager.save(self.context) }.to(throwError { (error: NSError) in
            expect(error.code).to(equal(133021))
        })
    }

    let documentManager = DocumentManager()
    func testConflict() throws {
        let title = faker.zelda.game()

        let document1 = Document.create(context, title: title)
        expect { try CoreDataManager.save(self.context) }.toNot(throwError())
        var document2: Document!
        backgroundContext.performAndWait {
            // swiftlint:disable:next force_cast
            document2 = (backgroundContext.object(with: document1.objectID) as! Document)
        }

        document1.title = "another title"
        document2.title = "3rd title"

        expect { try CoreDataManager.save(self.backgroundContext) }.toNot(throwError())
        DocumentManager.saveContext(context: self.backgroundContext) { result in
            expect { try result.get() }.toNot(throwError())
        }

        expect { try CoreDataManager.save(self.context) }.to(throwError { (error: NSError) in
            expect(error.code).to(equal(133020))
        })
        DocumentManager.saveContext(context: context) { result in
            expect { try result.get() }.to(throwError { (error: NSError) in
                expect(error.code).to(equal(133020))
            })
        }

        expect(document1.title).to(equal("another title"))
        context.refresh(document1, mergeChanges: false)
        expect(document1.title).to(equal("3rd title"))
    }
}
