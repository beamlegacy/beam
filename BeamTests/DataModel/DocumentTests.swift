import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

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

            sut = DocumentManager(coreDataManager: coreDataManager)
            mainContext = sut.context
            backgroundContext = coreDataManager.backgroundContext
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                     coreDataManager: coreDataManager)

            helper.deleteAllDocuments()
        }

        afterEach {
            BeamDate.reset()
            helper.deleteAllDocuments()
        }

        describe(".count()") {
            it("fetches document") {
                let count = 3
                let countBefore = sut.count()

                for _ in 1...count {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)
                }

                let countAfter = sut.count()
                expect(countAfter) >= countBefore + count
                // Because sometimes BeamNote adds today's journal note
                expect(countAfter) <= countBefore + count + 1
            }
        }

        describe(".fetchWithTitle()") {
            // Checks https://linear.app/beamapp/issue/BE-1116/sqlcore-crash-in-documentfetchfirst-when-typing-/-in-omnibar
            // Typing `\` in Omnibar used to crash
            it("doesn't crash with \\") {
                expect {
                    try sut.fetchWithTitle("\\")
                }.toNot(throwError())
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

                let result = try! sut.fetchAllWithTitleMatch(title: "foobar", limit: 0)
                expect(result).to(haveCount(times))
                expect(result[0].title).to(equal("foobar"))
                expect(result[1].title).to(equal("foobar 1"))
            }
        }

        describe("MD5") {
            it("generates the same MD5 as Ruby") {
                let document: Document = try sut.create(id: UUID(), title: "foobar")
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

                let document1: Document = try sut.create(id: UUID(), title: title)
                let document2: Document = try sut.create(id: UUID(), title: title + "2")

                document1.id = id
                document2.id = id
                document2.title = title

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

                let document1: Document = try sut.create(id: UUID(), title: title)
                expect { try CoreDataManager.save(mainContext) }.toNot(throwError())
                var document2: Document!
                backgroundContext.performAndWait {
                    // swiftlint:disable:next force_cast
                    document2 = (backgroundContext.object(with: document1.objectID) as! Document)
                }

                document1.title = title2
                document2.title = title3

                expect { try CoreDataManager.save(backgroundContext) }.toNot(throwError())
                expect { try sut.saveContext() }.to(throwError { (error: CocoaError) in
                    expect(error.code) == CocoaError.Code.managedObjectMerge
                })
                expect { try sut.saveContext() }.to(throwError { (error: CocoaError) in
                    expect(error.code) == CocoaError.Code.managedObjectMerge
                })

                expect(document1.title).to(equal(title2))
                mainContext.refresh(document1, mergeChanges: false)
                expect(document1.title).to(equal(title3))
            }
        }
    }
}
