import Foundation
import XCTest

class CoreDataManagerTests: XCTestCase {

    // MARK: Properties

    var sut: CoreDataManager!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()

        sut = CoreDataManager()
    }

    // MARK: - Tests

    // MARK: Setup
    func test_setup_completionCalled() {
        let setupExpectation = expectation(description: "set up completion called")

        sut.setup {
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { (_) in
            XCTAssertTrue(self.sut.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0)
        }
    }

    func test_setup_persistentContainerLoadedOnDisk() {
        let setupExpectation = expectation(description: "set up completion called")

        sut.setup {
            XCTAssertEqual(self.sut.persistentContainer.persistentStoreDescriptions.first?.type, NSSQLiteStoreType)
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { (_) in
            self.sut.destroyPersistentStore()
        }
    }

    func test_setup_persistentContainerLoadedInMemory() {
        let setupExpectation = expectation(description: "set up completion called")

        sut.setup(storeType: NSInMemoryStoreType) {
            XCTAssertEqual(self.sut.persistentContainer.persistentStoreDescriptions.first?.type, NSInMemoryStoreType)
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func test_backgroundContext_concurrencyType() {
        let setupExpectation = expectation(description: "background context")

        sut.setup(storeType: NSInMemoryStoreType) {
            XCTAssertEqual(self.sut.backgroundContext.concurrencyType, .privateQueueConcurrencyType)
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func test_mainContext_concurrencyType() {
        let setupExpectation = expectation(description: "main context")

        sut.setup(storeType: NSInMemoryStoreType) {
            XCTAssertEqual(self.sut.mainContext.concurrencyType, .mainQueueConcurrencyType)
            setupExpectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
