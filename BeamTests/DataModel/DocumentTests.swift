import Foundation
import Fakery

import XCTest
@testable import Beam

class DocumentTests: CoreDataTests {
    let faker = Faker(locale: "en-US")

    func testDocumentFetch() throws {
        let countBefore = Document.countWithPredicate(context)
        XCTAssertEqual(countBefore, 0)

        let count = 3

        for _ in 1...count {
            _ = Document.create(context, title: faker.lorem.words())
        }

        let countAfter = Document.countWithPredicate(context)

        XCTAssertEqual(countAfter, countBefore + count)
    }

    func testDocumentFetchWithTitle() throws {
        _ = Document.create(context, title: "foobar 1")
        _ = Document.create(context, title: "foobar 2")
        _ = Document.create(context, title: "foobar 3")
        _ = Document.create(context, title: "another title")

        XCTAssertEqual(Document.fetchAllWithTitleMatch(context, "foobar").count, 3)
    }

    func testMD5() throws {
        let document = Document.create(context, title: "foobar")
        document.data = "foobar".data(using: .utf8)
        // Calculated from Ruby with Digest::MD5.hexdigest "foobar"
        XCTAssertEqual(document.data?.MD5, "3858f62230ac3c915f300c664312c63f")
    }

    func testDuplicateIds() throws {
        let id = UUID()
        let title = faker.zelda.game()

        let document1 = Document.create(context, title: title)
        let document2 = Document.create(context, title: title)

        document1.id = id
        document2.id = id

        XCTAssertThrowsError(try CoreDataManager.save(context)) { error in
            // This is the cocoa code for constraint error
            XCTAssertEqual((error as NSError).code, 133021)
        }
    }
}
