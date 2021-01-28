import Foundation
import XCTest
import Nimble

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

        // Can't use `NSInMemoryStoreType` as model constraints don't work
        // storeType: NSInMemoryStoreType
        coreDataManager.setup()
        waitUntil { done in
            self.coreDataManager.destroyPersistentStore {
                self.coreDataManager.setup()
                done()
            }
        }

        CoreDataManager.shared = coreDataManager
    }
}
