import Foundation
import XCTest
import Fakery
import AnyCodable

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
    struct DataDocument: Encodable {
        var bullets: [DataBullet]
        // swiftlint:disable:next nesting
        struct DataBullet: Encodable {
            let content: String
            let updatedAt: Date
        }
    }

    // MARK: - Tests
    func testSave() throws {
        let setupExpectation = expectation(description: "set up completion called")

        let data = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                          DataDocument.DataBullet(content: "line 2", updatedAt: Date())])

        let id = UUID()
        let title = faker.zelda.game()

        sut.saveDocument(id: id, title: title, data: data) {
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            let count = Document.countWithPredicate(self.context)
            XCTAssertEqual(count, 1)
        }
    }

    func testAnyDecodable() throws {
        let json = """
             {
                 "boolean": true,
                 "integer": 1,
                 "double": 3.141592653589793,
                 "string": "string",
                 "array": [1, 2, 3],
                 "nested": {
                     "a": "alpha",
                     "b": "bravo",
                     "c": "charlie"
                 }
             }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        //swiftlint:disable force_cast
        if let dictionary = try? decoder.decode([String: AnyDecodable].self, from: json) {
            let arrayData = dictionary["array"]!.value as! [Int]
            XCTAssertEqual(arrayData.first, 1)

            let nestedData = dictionary["nested"]!.value as! [String: String]
            XCTAssertEqual(nestedData["a"], "alpha")
        }
        //swiftlint:enable force_cast
    }

    func testLoad() throws {
        let setupExpectation = expectation(description: "set up completion called")

        let data = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                          DataDocument.DataBullet(content: "line 2", updatedAt: Date())])
        let id = UUID()
        let title = faker.zelda.game()

        sut.saveDocument(id: id, title: title, data: data) {
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            var document = self.sut.loadDocumentById(id: id)
            XCTAssertNotNil(document)

            document = self.sut.loadDocumentByTitle(title: title)
            XCTAssertNotNil(document)

            //swiftlint:disable:next force_cast
            let documentInternalData = document!.data

            //swiftlint:disable:next force_cast
            let result = DataDocument(data: documentInternalData)!

            XCTAssertEqual(result.bullets.first?.content, "line 1")
            XCTAssertEqual(result.bullets.last?.content, "line 2")
        }
    }

    func testDelete() throws {
        let data = DataDocument(bullets: [DataDocument.DataBullet(content: "line 1", updatedAt: Date()),
                                          DataDocument.DataBullet(content: "line 2", updatedAt: Date())])

        let id = UUID()
        let title = faker.zelda.game()

        let saveExpectation = expectation(description: "save completion called")
        sut.saveDocument(id: id, title: title, data: data) {
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

extension DocumentManagerTests.DataDocument {
    init?(data: AnyDecodable) {
        guard let value = data.value as? [String: Any],
              let bullets = value["bullets"] as? [Any] else { return nil }

        self.bullets = []

        for bullet in bullets {
            if let newBullet = DocumentManagerTests.DataDocument.DataBullet(data: bullet) {
                self.bullets.append(newBullet)
            }
        }
    }
}

extension DocumentManagerTests.DataDocument.DataBullet {
    init?(data: Any) {
        let dateFormatter = ISO8601DateFormatter()

        guard let bulletDictionary = data as? [String: Any],
              let content = bulletDictionary["content"] as? String,
              let dateString = bulletDictionary["updatedAt"] as? String,
              let updatedAt = dateFormatter.date(from: dateString) else {
            return nil
        }
        self.content = content
        self.updatedAt = updatedAt
    }
}
