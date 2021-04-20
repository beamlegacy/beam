import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class DocumentTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        // MARK: Properties
        var sut: DocumentManager!
        var helper: DocumentManagerTestsHelper!
        var coreDataManager: CoreDataManager!
        var mainContext: NSManagedObjectContext!
        var backgroundContext: NSManagedObjectContext!

        beforeEach {
            coreDataManager = CoreDataManager()

            // Setup CoreData
            coreDataManager.setup()
            //CoreDataManager.shared = coreDataManager

            mainContext = coreDataManager.mainContext
            backgroundContext = coreDataManager.backgroundContext
            sut = DocumentManager(coreDataManager: coreDataManager)
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                     coreDataManager: coreDataManager)

            helper.deleteAllDocuments()
        }

        afterEach {
            BeamDate.reset()
        }

        describe(".countWithPredicate()") {
            it("fetches document") {
                let count = 3
                let countBefore = Document.countWithPredicate(mainContext)

                for _ in 1...count {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)
                }

                let countAfter = Document.countWithPredicate(mainContext)
                expect(countAfter) >= countBefore + count
                // Because sometimes BeamNote adds today's journal note
                expect(countAfter) <= countBefore + count + 1
            }
        }

        describe(".updatedAt") {
            it("updates attribute on context save only if more than a second difference, and has data changes") {
                let document = Document.create(mainContext, title: String.randomTitle())
                expect(document.updated_at).toNot(beNil())

                BeamDate.travel(0.5)
                let initialUpdatedAt = document.updated_at
                document.title = String.randomTitle()
                try? mainContext.save()
                expect(document.updated_at) == initialUpdatedAt

                BeamDate.travel(1.5)
                document.title = String.randomTitle()
                document.data = String.randomTitle().asData // force updatedAt change
                try? mainContext.save()
                expect(document.updated_at).toNot(equal(initialUpdatedAt))
                expect(document.updated_at).to(beGreaterThan(initialUpdatedAt))
                expect(document.updated_at.timeIntervalSince(initialUpdatedAt)).to(beGreaterThan(2.0))
            }
        }

        describe(".fetchAllWithTitleMatch()") {
            it("fetches documents matching title") {
                let times = 3
                for index in 1..<times {
                    _ = helper.saveLocally(helper.createDocumentStruct(title: "foobar \(index)"))
                }
                _ = helper.saveLocally(helper.createDocumentStruct())
                _ = helper.saveLocally(helper.createDocumentStruct(title: "foobar"))

                let result = try! Document.fetchAllWithTitleMatch(mainContext, "foobar")
                expect(result).to(haveCount(times))
                expect(result[0].title).to(equal("foobar"))
                expect(result[1].title).to(equal("foobar 1"))
            }
        }

        describe("MD5") {
            it("generates the same MD5 as Ruby") {
                let document = Document.create(mainContext, title: "foobar")
                document.data = "foobar".data(using: .utf8)
                // Calculated from Ruby with Digest::MD5.hexdigest "foobar"
                expect(document.data?.MD5).to(equal("3858f62230ac3c915f300c664312c63f"))
            }
        }

        describe("JSON encoding") {
            let encoder = JSONEncoder()
            let text = "this is a text"
            let base64EncodedText = text.asData.base64EncodedString()
            let expectedJson = "{\"data\":\"\(base64EncodedText)\"}"

            struct Foobar: Codable {
                let data: Data
            }

            it("generates a string with base64 encoded data") {
                let newstruct = Foobar(data: text.asData)
                let data = try encoder.encode(newstruct)

                expect(data.asString) == expectedJson
                expect(Data(base64Encoded: base64EncodedText)?.asString) == text
            }
        }

        describe(".id") {
            it("should check for constraints") {
                let id = UUID()
                let title = String.randomTitle()

                let document1 = Document.create(mainContext, title: title)
                let document2 = Document.create(mainContext, title: title)

                document1.id = id
                document2.id = id

                expect { try CoreDataManager.save(mainContext) }.to(throwError { (error: CocoaError) in
                    expect(error.code) == CocoaError.Code.managedObjectConstraintMerge
                })

                mainContext.delete(document1)
                mainContext.delete(document2)
            }
        }

        describe(".title") {
            it("should check for constraints") {
                let title = String.randomTitle()
                let title2 = String.randomTitle()
                let title3 = String.randomTitle()

                let document1 = Document.create(mainContext, title: title)
                expect { try CoreDataManager.save(mainContext) }.toNot(throwError())
                var document2: Document!
                backgroundContext.performAndWait {
                    // swiftlint:disable:next force_cast
                    document2 = (backgroundContext.object(with: document1.objectID) as! Document)
                }

                document1.title = title2
                document2.title = title3

                expect { try CoreDataManager.save(backgroundContext) }.toNot(throwError())
                expect { try DocumentManager.saveContext(context: backgroundContext) }.toNot(throwError())

                expect { try CoreDataManager.save(mainContext) }.to(throwError { (error: CocoaError) in
                    expect(error.code) == CocoaError.Code.managedObjectMerge
                })
                expect { try DocumentManager.saveContext(context: mainContext) }.to(throwError { (error: CocoaError) in
                    expect(error.code) == CocoaError.Code.managedObjectMerge
                })

                expect(document1.title).to(equal(title2))
                mainContext.refresh(document1, mergeChanges: false)
                expect(document1.title).to(equal(title3))
            }
        }
    }
}
