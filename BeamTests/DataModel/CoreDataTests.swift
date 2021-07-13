import Foundation
import XCTest
import Nimble

@testable import Beam

class CoreDataTests: XCTestCase {
    lazy var coreDataManager = {
        CoreDataManager(storeType: NSInMemoryStoreType)
    }()
    lazy var context = {
        coreDataManager.mainContext
    }()
    lazy var backgroundContext = {
        coreDataManager.backgroundContext
    }()
    override func setUp() {
        super.setUp()

        coreDataManager.setup()

        CoreDataManager.shared = coreDataManager
    }
}
