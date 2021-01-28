import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

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

        waitUntil { [unowned self] done in
            self.sut.saveDocument(docStruct) { _ in
                done()
            }
        }

        let count = Document.countWithPredicate(self.context,
                                                NSPredicate(format: "id = %@", id as CVarArg))
        expect(count).to(equal(1))
    }

    func testLoad() throws {
        let data = "whatever binary data"

        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(data)
        let id = UUID()
        let title = faker.zelda.game()

        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: Date(),
                                       updatedAt: Date(),
                                       data: jsonData,
                                       documentType: .note)

        waitUntil { [unowned self] done in
            self.sut.saveDocument(docStruct) { _ in
                done()
            }
        }

        var document = self.sut.loadDocumentById(id: id)
        expect(document).toNot(beNil())

        document = self.sut.loadDocumentByTitle(title: title)
        expect(document).toNot(beNil())

        //swiftlint:disable:next force_cast
        //swiftlint:disable:next force_try
        let result = try! self.defaultDecoder().decode(String.self, from: document!.data)

        expect(result).to(equal(data))
    }

    func testDelete() throws {
        let data = "whatever binary data"

        let id = UUID()
        let title = faker.zelda.game()
        //swiftlint:disable force_try
        let jsonData = try! self.defaultEncoder().encode(data)

        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: Date(),
                                       updatedAt: Date(),
                                       data: jsonData,
                                       documentType: .note)

        waitUntil { [unowned self] done in
            self.sut.saveDocument(docStruct) { _ in
                done()
            }
        }

        var count = Document.countWithPredicate(self.context, NSPredicate(format: "id = %@", id as
                                                                            CVarArg))
        expect(count).to(equal(1))

        waitUntil { [unowned self] done in
            self.sut.deleteDocument(id: id) { _ in
                done()
            }
        }

        count = Document.countWithPredicate(self.context, NSPredicate(format: "id = %@", id as
                                                                            CVarArg))

        expect(count).to(equal(0))
    }

    // swiftlint:disable:next function_body_length
    func testDuplicateTitles() throws {
        let data = "whatever binary data"

        //swiftlint:disable:next force_try
        var jsonData = try! self.defaultEncoder().encode(data)

        let id = UUID()
        let title = faker.zelda.game()

        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: Date(),
                                       updatedAt: Date(),
                                       data: jsonData,
                                       documentType: .note)

        waitUntil { [unowned self] done in
            self.sut.saveDocument(docStruct) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }

        //swiftlint:disable:next force_try
        jsonData = try! self.defaultEncoder().encode(data)

        var docStruct2 = DocumentStruct(id: UUID(),
                                        title: title,
                                        createdAt: Date(),
                                        updatedAt: Date(),
                                        data: jsonData,
                                        documentType: .note)

        waitUntil { [unowned self] done in
            self.sut.saveDocument(docStruct2) { result in
                expect { try result.get() }.to(throwError())
                done()
            }
        }

        var count = Document.countWithPredicate(self.context,
                                                NSPredicate(format: "id = %@", id as CVarArg))
        expect(count).to(equal(1))

        docStruct2.deletedAt = Date()

        waitUntil { [unowned self] done in
            self.sut.saveDocument(docStruct2, completion: { result in
                expect { try result.get() }.toNot(throwError())
                done()
            })
        }

        count = Document.rawCountWithPredicate(self.context,
                                               NSPredicate(format: "title = %@", title),
                                               onlyNonDeleted: false)
        expect(count).to(equal(2))
    }

    func testDocumentCreate() throws {
        let title = faker.zelda.game()
        let documentStruct = sut.create(title: title)
        expect(documentStruct?.title).to(equal(title))
    }

    func testDocumentCreateAsync() throws {
        let title = faker.zelda.game()

        waitUntil { [unowned self] done in
            self.sut.createAsync(title: title) { documentStruct in
                expect(documentStruct?.title).to(equal(title))
                done()
            }
        }
    }

    func testDocumentFetchOrCreate() throws {
        let title = faker.zelda.game()
        let documentStruct = sut.fetchOrCreate(title: title)
        expect(documentStruct?.title).to(equal(title))

        let documentStruct2 = sut.fetchOrCreate(title: title)
        expect(documentStruct2?.title).to(equal(title))

        expect(documentStruct?.id).notTo(beNil())
        expect(documentStruct?.id).to(equal(documentStruct2?.id))
    }

    func testDocumentFetchOrCreateAsync() throws {
        let title = faker.zelda.game()

        waitUntil { [unowned self] done in
            self.sut.fetchOrCreateAsync(title: title) { documentStruct in
                expect(documentStruct?.title).to(equal(title))
                done()
            }
        }
    }

    func testDocumentCreateAsync2() throws {
        // Just a simple example showing the use of semaphores to wait for async jobs
        let semaphore = DispatchSemaphore(value: 0)
        let title = faker.zelda.game()

        sut.createAsync(title: title) { documentStruct in
            XCTAssertEqual(documentStruct?.title, title)
            semaphore.signal()
        }

        semaphore.wait()
    }

    func testOnDocumentUpdate() throws {
        let title = faker.zelda.game()
        let newTitle = "a new title"
        expect(title).toNot(equal(newTitle))
        let document = Document.create(context, title: title)
        document.data = Data()
        //swiftlint:disable:next force_try
        try! context.save()

        let documentStruct = sut.loadDocumentById(id: document.id)!

        waitUntil { [unowned self] done in
            let cancellable = self.sut.onDocumentChange(documentStruct) { updatedDocumentStruct in
                expect(documentStruct.id).to(equal(updatedDocumentStruct.id))
                expect(updatedDocumentStruct.title).to(equal(newTitle))
                done()
            }

            document.title = newTitle
            //swiftlint:disable:next force_try
            try! context.save()

            // To avoid warning
            cancellable.cancel()
        }
    }
}
