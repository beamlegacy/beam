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

        // We don't want to be authenticated when running test on our desktop
        // Xcode while being authenticated in the app
        Persistence.Authentication.accessToken = nil
    }

    override func tearDownWithError() throws {
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

        let document = "whatever binary data"

        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(document)

        let id = UUID()
        let title = faker.zelda.game()
        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: Date(),
                                       updatedAt: Date(),
                                       data: jsonData,
                                       documentType: .note)

        sut.saveDocument(docStruct, completion: { _ in
            setupExpectation.fulfill()
        })

        waitForExpectations(timeout: 1.0) { _ in
            let count = Document.countWithPredicate(self.context, NSPredicate(format: "id = %@", id as CVarArg))
            XCTAssertEqual(count, 1)
        }
    }

    func testLoad() throws {
        let setupExpectation = expectation(description: "set up completion called")

        let document = "whatever binary data"

        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(document)
        let id = UUID()
        let title = faker.zelda.game()

        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: Date(),
                                       updatedAt: Date(),
                                       data: jsonData,
                                       documentType: .note)

        sut.saveDocument(docStruct, completion: { _ in
            setupExpectation.fulfill()
        })

        waitForExpectations(timeout: 1.0) { _ in
            var document = self.sut.loadDocumentById(id: id)
            XCTAssertNotNil(document)

            document = self.sut.loadDocumentByTitle(title: title)
            XCTAssertNotNil(document)

            //swiftlint:disable:next force_cast
            //swiftlint:disable:next force_try
            let result = try! self.defaultDecoder().decode(String.self, from: document!.data)

            XCTAssertEqual(result, "whatever binary data")
        }
    }

    func testDelete() throws {
        let document = "whatever binary data"

        let id = UUID()
        let title = faker.zelda.game()
        //swiftlint:disable force_try
        let jsonData = try! self.defaultEncoder().encode(document)

        let saveExpectation = expectation(description: "save completion called")
        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: Date(),
                                       updatedAt: Date(),
                                       data: jsonData,
                                       documentType: .note)

        sut.saveDocument(docStruct, completion: { _ in
            saveExpectation.fulfill()
        })

        waitForExpectations(timeout: 2.0) { _ in
            let count = Document.countWithPredicate(self.context, NSPredicate(format: "id = %@", id as CVarArg))
            XCTAssertEqual(count, 1)
        }

        let deleteExpectation = expectation(description: "delete completion called")
        sut.deleteDocument(id: id) { _ in
            deleteExpectation.fulfill()
        }

        waitForExpectations(timeout: 2.0) { _ in
            let count = Document.countWithPredicate(self.context, NSPredicate(format: "id = %@", id as CVarArg))
            XCTAssertEqual(count, 0)
        }
    }

    // swiftlint:disable:next function_body_length
    func testDuplicateTitles() throws {
        let saveExpectation = expectation(description: "save completion called")

         let document = "whatever binary data"

         //swiftlint:disable:next force_try
         var jsonData = try! self.defaultEncoder().encode(document)

         let id = UUID()
         let title = faker.zelda.game()

         let docStruct = DocumentStruct(id: id,
                                        title: title,
                                        createdAt: Date(),
                                        updatedAt: Date(),
                                        data: jsonData,
                                        documentType: .note)

         sut.saveDocument(docStruct, completion: { _ in
             DispatchQueue.main.async {
                 saveExpectation.fulfill()
             }
         })

         waitForExpectations(timeout: 1.0) { _ in
         }

         // Create another one with same title
         let saveDoubleExpectations = expectation(description: "save completion called")
         //swiftlint:disable:next force_try
         jsonData = try! self.defaultEncoder().encode(document)

         var docStruct2 = DocumentStruct(id: UUID(),
                                         title: title,
                                         createdAt: Date(),
                                         updatedAt: Date(),
                                         data: jsonData,
                                         documentType: .note)

         sut.saveDocument(docStruct2, completion: { result in
             switch result {
             case .success:
                 XCTAssert(false)
             case .failure:
                 break
             }

             DispatchQueue.main.async {
                 saveDoubleExpectations.fulfill()
             }
         })

         waitForExpectations(timeout: 1.0) { _ in
             let count = Document.countWithPredicate(self.context,
                                                     NSPredicate(format: "id = %@", id as CVarArg))
             XCTAssertEqual(count, 1)
         }

        docStruct2.deletedAt = Date()
        let saveDoubleOkExpectations = expectation(description: "save completion called")
        sut.saveDocument(docStruct2, completion: { result in
            switch result {
            case .success: break
            case .failure:
                XCTAssert(false)
            }

            DispatchQueue.main.async {
                saveDoubleOkExpectations.fulfill()
            }
        })
        waitForExpectations(timeout: 1.0) { _ in
            let count = Document.rawCountWithPredicate(self.context,
                                                       NSPredicate(format: "title = %@", title),
                                                       onlyNonDeleted: false)
            XCTAssertEqual(count, 2)
        }
    }
}
