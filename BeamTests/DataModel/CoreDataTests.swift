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
    lazy var backgroundContext = {
        coreDataManager.backgroundContext
    }()
    override func setUp() {
        super.setUp()

        // Can't use `NSInMemoryStoreType` as model constraints don't work
        // storeType: NSInMemoryStoreType
        coreDataManager.setup()

        CoreDataManager.shared = coreDataManager
    }

    override func tearDown() {
        coreDataManager.destroyPersistentStore()
    }
}
