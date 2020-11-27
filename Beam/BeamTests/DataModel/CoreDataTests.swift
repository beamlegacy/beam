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

        coreDataManager.setup(storeType: NSInMemoryStoreType)
        CoreDataManager.shared = coreDataManager
    }
}
