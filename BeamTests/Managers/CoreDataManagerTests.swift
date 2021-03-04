import Foundation
import Quick
import Nimble

@testable import Beam
class CoreDataManagerTests: QuickSpec {
    override func spec() {
        var sut: CoreDataManager!

        beforeSuite {
            sut = CoreDataManager()
            sut.setup()
        }

        it("has SQLite store") {
            expect(sut.persistentContainer.persistentStoreDescriptions.first?.type).to(equal(NSSQLiteStoreType))
        }

        describe(".importBackup(url)") {
            let url = Bundle(for: type(of: self)).url(forResource: "BeamExport", withExtension: "sqlite")!

            beforeEach {
                sut.destroyPersistentStore()
            }

            it("loads new objects from backup") {
                sut.importBackup(url)
                expect(Document.fetchAll(context: sut.mainContext).map { $0.title }) == ["4 March 2021"]
            }
        }
    }
}
