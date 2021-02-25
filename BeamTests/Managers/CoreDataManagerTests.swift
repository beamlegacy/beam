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

    // MARK: Setup
    func test_setup_persistentContainerLoadedOnDisk() {
        self.sut.setup()
        expect(self.sut.persistentContainer.persistentStoreDescriptions.first?.type).to(equal(NSSQLiteStoreType))
    }
}
