import Foundation
import XCTest
@testable import Beam

class CoreDataTests: XCTestCase {
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var context = {
        coreDataManager.mainContext
    }()
    override func setUp() {
        super.setUp()

        let setupExpectation = expectation(description: "setup completion called")

        // Can't use `NSInMemoryStoreType` as model constraints don't work
         // storeType: NSInMemoryStoreType
        coreDataManager.setup()
        coreDataManager.destroyPersistentStore {
            self.coreDataManager.setup()
            setupExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0) { _ in
        }

        CoreDataManager.shared = coreDataManager
    }
}
