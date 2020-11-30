import Foundation
import XCTest
import Fakery

@testable import Beam
class DocumentManagerTests: CoreDataTests {
    let faker = Faker(locale: "en-US")

    // MARK: Properties
    var sut: DocumentManager!

    // MARK: - Lifecycle
    override func setUp() {
        super.setUp()

        sut = DocumentManager(coreDataManager: coreDataManager)
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Structs
    struct DataDocument: Codable {
        var bullets: [DataBullet]
        // swiftlint:disable:next nesting
        struct DataBullet: Codable {
            let content: String
            let updatedAt: Date
        }
    }

    func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func defaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Tests
    func testSave() throws {
        let setupExpectation = expectation(description: "set up completion called")

        let document = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                              DataDocument.DataBullet(content: "line 2", updatedAt: Date())])

        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(document)

        let id = UUID()
        let title = faker.zelda.game()

        sut.saveDocument(id: id, title: title, data: jsonData) { _ in
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            let count = Document.countWithPredicate(self.context)
            XCTAssertEqual(count, 1)
        }
    }

    func testDuplicate() throws {
        let saveExpectation = expectation(description: "save completion called")

        let document = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                              DataDocument.DataBullet(content: "line 2", updatedAt: Date())])

        //swiftlint:disable:next force_try
        var jsonData = try! self.defaultEncoder().encode(document)

        let id = UUID()
        let title = faker.zelda.game()

        sut.saveDocument(id: id, title: title, data: jsonData) { _ in
            saveExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
        }

        // Create another one with different ID, same title
        let saveDoubleExpectations = expectation(description: "save completion called")
        //swiftlint:disable:next force_try
        jsonData = try! self.defaultEncoder().encode(document)

        sut.saveDocument(id: UUID(), title: title, data: jsonData) { result in
            switch result {
            case .success:
                XCTAssert(false)
            case .failure:
                break
            }

            saveDoubleExpectations.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            let count = Document.countWithPredicate(self.context)
            XCTAssertEqual(count, 1)
        }
    }

    func testLoad() throws {
        let setupExpectation = expectation(description: "set up completion called")

        let document = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                              DataDocument.DataBullet(content: "line 2", updatedAt: Date())])
        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(document)
        let id = UUID()
        let title = faker.zelda.game()

        sut.saveDocument(id: id, title: title, data: jsonData) { _ in
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            var document = self.sut.loadDocumentById(id: id)
            XCTAssertNotNil(document)

            document = self.sut.loadDocumentByTitle(title: title)
            XCTAssertNotNil(document)

            //swiftlint:disable:next force_cast
            //swiftlint:disable:next force_try
            let result = try! self.defaultDecoder().decode(DataDocument.self, from: document!.data)

            XCTAssertEqual(result.bullets.first?.content, "line 1")
            XCTAssertEqual(result.bullets.last?.content, "line 2")
        }
    }

    func testDelete() throws {
        let document = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                              DataDocument.DataBullet(content: "line 2", updatedAt: Date())])

        let id = UUID()
        let title = faker.zelda.game()
        //swiftlint:disable force_try
        let jsonData = try! self.defaultEncoder().encode(document)

        let saveExpectation = expectation(description: "save completion called")
        sut.saveDocument(id: id, title: title, data: jsonData) { _ in
            saveExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0) { _ in
            let count = Document.countWithPredicate(self.context)
            XCTAssertEqual(count, 1)
        }

        let deleteExpectation = expectation(description: "delete completion called")
        sut.deleteDocument(id: id) {
            deleteExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0) { _ in
            let count = Document.countWithPredicate(self.context)
            XCTAssertEqual(count, 0)
        }
    }
}
