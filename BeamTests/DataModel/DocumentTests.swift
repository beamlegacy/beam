import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class DocumentTests: QuickSpec {
    // MARK: Properties
    var sut: DocumentManager!
    var helper: DocumentManagerTestsHelper!
    var coreDataManager: CoreDataManager!
    var mainContext: NSManagedObjectContext!
    var backgroundContext: NSManagedObjectContext!

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeEach {
            self.coreDataManager = CoreDataManager()
            self.mainContext = self.coreDataManager.mainContext
            self.backgroundContext = self.coreDataManager.backgroundContext

            // Setup CoreData
            self.coreDataManager.setup()
            CoreDataManager.shared = self.coreDataManager
            self.sut = DocumentManager(coreDataManager: self.coreDataManager)
            self.helper = DocumentManagerTestsHelper(documentManager: self.sut,
                                                     coreDataManager: self.coreDataManager)
        }

        afterEach {
            BeamDate.reset()
        }

        describe(".countWithPredicate()") {
            it("fetches document") {
                try? self.mainContext.save()

                let count = 3
                let countBefore = Document.countWithPredicate(self.mainContext)

                for _ in 1...count {
                    self.helper.saveLocally(self.helper.createDocumentStruct())
                }

                let countAfter = Document.countWithPredicate(self.mainContext)
                expect(countAfter).to(equal(countBefore + count))
            }
        }

        describe(".updatedAt") {
            it("updates attribute on context save only if more than a second difference") {
                let document = Document.create(self.mainContext, title: self.helper.title())
                expect(document.updated_at).toNot(beNil())

                BeamDate.travel(0.5)
                let initialUpdatedAt = document.updated_at
                document.title = self.helper.title()
                try? self.mainContext.save()
                expect(document.updated_at).to(equal(initialUpdatedAt))

                BeamDate.travel(1.5)
                document.title = self.helper.title()
                try? self.mainContext.save()
                expect(document.updated_at).toNot(equal(initialUpdatedAt))
                expect(document.updated_at).to(beGreaterThan(initialUpdatedAt))
                expect(document.updated_at.timeIntervalSince(initialUpdatedAt)).to(beGreaterThan(2.0))
            }
        }

        describe(".fetchAllWithTitleMatch()") {
            it("fetches documents matching title") {
                self.helper.saveLocally(self.helper.createDocumentStruct(title: "foobar 1"))
                self.helper.saveLocally(self.helper.createDocumentStruct(title: "foobar 2"))
                self.helper.saveLocally(self.helper.createDocumentStruct(title: "foobar 3"))
                self.helper.saveLocally(self.helper.createDocumentStruct())

                expect(Document.fetchAllWithTitleMatch(self.mainContext, "foobar")).to(haveCount(3))
            }
        }

        describe("MD5") {
            it("generates the same MD5 as Ruby") {
                let document = Document.create(self.mainContext, title: "foobar")
                document.data = "foobar".data(using: .utf8)
                // Calculated from Ruby with Digest::MD5.hexdigest "foobar"
                expect(document.data?.MD5).to(equal("3858f62230ac3c915f300c664312c63f"))
            }
        }

        describe(".id") {
            it("should check for constraints") {
                let id = UUID()
                let title = self.helper.title()

                let document1 = Document.create(self.mainContext, title: title)
                let document2 = Document.create(self.mainContext, title: title)

                document1.id = id
                document2.id = id

                expect { try CoreDataManager.save(self.mainContext) }.to(throwError { (error: NSError) in
                    expect(error.code).to(equal(133021))
                })

                self.mainContext.delete(document1)
                self.mainContext.delete(document2)
            }
        }

        describe(".title") {
            it("should check for constraints") {
                let title = self.helper.title()
                let title2 = self.helper.title()
                let title3 = self.helper.title()

                let document1 = Document.create(self.mainContext, title: title)
                expect { try CoreDataManager.save(self.mainContext) }.toNot(throwError())
                var document2: Document!
                self.backgroundContext.performAndWait {
                    // swiftlint:disable:next force_cast
                    document2 = (self.backgroundContext.object(with: document1.objectID) as! Document)
                }

                document1.title = title2
                document2.title = title3

                expect { try CoreDataManager.save(self.backgroundContext) }.toNot(throwError())
                expect { try DocumentManager.saveContext(context: self.backgroundContext) }.toNot(throwError())

                expect { try CoreDataManager.save(self.mainContext) }.to(throwError { (error: NSError) in
                    expect(error.code).to(equal(133020))
                })
                expect { try DocumentManager.saveContext(context: self.mainContext) }.to(throwError { (error: NSError) in
                    expect(error.code).to(equal(133020))
                })

                expect(document1.title).to(equal(title2))
                self.mainContext.refresh(document1, mergeChanges: false)
                expect(document1.title).to(equal(title3))
            }
        }
    }
}
