import Foundation
import XCTest
import Fakery

@testable import Beam
class DocumentManagerTests: XCTestCase {
    let faker = Faker(locale: "en-US")

    // MARK: Properties
    var sut: DocumentManager!
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var context = {
        coreDataManager.mainContext
    }()

    // MARK: - Lifecycle
    override func setUp() {
        super.setUp()

        sut = DocumentManager(coreDataManager: coreDataManager)
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Structs
    struct DataBullet: Encodable {
        let content: String
        let updatedAt: Date
    }

    struct Data: Encodable {
        let bullets: [DataBullet]
    }

    // MARK: - Tests

    func testSave() throws {
        let setupExpectation = expectation(description: "set up completion called")

        let data = Data(bullets: [DataBullet(content: "line 1", updatedAt: Date()),
                                  DataBullet(content: "line 2", updatedAt: Date())])
        let id = UUID()
        let title = faker.zelda.game()

        var count = 0

        sut.saveDocument(id: id, title: title, data: data) {
            self.coreDataManager.persistentContainer.performBackgroundTask { context in
                count = Document.countWithPredicate(self.context)
                print(count)
            }

            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(count, 1)
        }
    }
}
