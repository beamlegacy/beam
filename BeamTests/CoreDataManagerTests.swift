import Foundation
import XCTest
import Nimble

@testable import Beam
class CoreDataManagerTests: XCTestCase {

    // MARK: Properties

    var sut: CoreDataManager!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()

        sut = CoreDataManager()
    }

    override func tearDownWithError() throws {
        sut.destroyPersistentStore()
    }

    // MARK: - Tests

    // MARK: Setup
    func test_setup_completionCalled() {
        waitUntil { [unowned self] done in
            self.sut.setup {
                expect(self.sut.persistentContainer.persistentStoreCoordinator.persistentStores.count).to(equal(1))
                done()
            }
        }
    }

    func test_setup_persistentContainerLoadedOnDisk() {
        waitUntil { [unowned self] done in
            self.sut.setup {
                expect(self.sut.persistentContainer.persistentStoreDescriptions.first?.type).to(equal(NSSQLiteStoreType))
                done()
            }
        }
    }

    func test_setup_persistentContainerLoadedInMemory() {
        waitUntil { [unowned self] done in
            self.sut.setup(storeType: NSInMemoryStoreType) {
                expect(self.sut.persistentContainer.persistentStoreDescriptions.first?.type).to(equal(NSInMemoryStoreType))
                expect(self.sut.backgroundContext.concurrencyType).to(equal(.privateQueueConcurrencyType))
                expect(self.sut.mainContext.concurrencyType).to(equal(.mainQueueConcurrencyType))

                done()
            }
        }
    }
}
