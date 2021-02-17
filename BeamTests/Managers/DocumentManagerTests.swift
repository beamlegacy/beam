// swiftlint:disable file_length

import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class DocumentManagerTests: QuickSpec {
    var sut: DocumentManager!
    var helper: DocumentManagerTestsHelper!

    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeSuite {
            // Setup CoreData
            self.coreDataManager.setup()

            CoreDataManager.shared = self.coreDataManager
            self.sut = DocumentManager(coreDataManager: self.coreDataManager)
            self.helper = DocumentManagerTestsHelper(documentManager: self.sut,
                                                     coreDataManager: self.coreDataManager)
            self.helper.logout()
        }

        describe(".saveDocument()") {
            it("saves document") {
                let docStruct = self.helper.createDocumentStruct()
                waitUntil(timeout: .seconds(10)) { done in
                    self.sut.saveDocument(docStruct) { _ in
                        done()
                    }
                }

                let count = Document.countWithPredicate(self.mainContext,
                                                        NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                expect(count).to(equal(1))
            }

            context("with duplicate titles") {
                it("should raise error") {
                    let docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)

                    var docStruct2 = self.helper.createDocumentStruct()
                    docStruct2.title = docStruct.title

                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.saveDocument(docStruct2) { result in
                            expect { try result.get() }.to(throwError())
                            done()
                        }
                    }

                    docStruct2.deletedAt = Date()

                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut.saveDocument(docStruct2) { result in
                            expect { try result.get() }.toNot(throwError())
                            done()
                        }
                    }

                    let count = Document.rawCountWithPredicate(self.mainContext,
                                                           NSPredicate(format: "title = %@", docStruct.title),
                                                           onlyNonDeleted: false)
                    expect(count).to(equal(2))
                }
            }
        }

        describe(".loadDocumentById()") {
            it("loads document") {
                let docStruct = self.helper.createDocumentStruct()
                self.helper.saveLocally(docStruct)

                let document = self.sut.loadDocumentById(id: docStruct.id)
                expect(document).toNot(beNil())
                expect(document?.title).to(equal(docStruct.title))
                expect(document?.data).to(equal(docStruct.data))
            }
        }

        describe(".loadDocumentByTitle()") {
            it("loads document") {
                let docStruct = self.helper.createDocumentStruct()
                self.helper.saveLocally(docStruct)

                let document = self.sut.loadDocumentByTitle(title: docStruct.title)
                expect(document).toNot(beNil())
                expect(document?.id).to(equal(docStruct.id))
                expect(document?.data).to(equal(docStruct.data))
            }
        }

        describe(".delete()") {
            it("deletes document") {
                let docStruct = self.helper.createDocumentStruct()
                self.helper.saveLocally(docStruct)
                waitUntil(timeout: .seconds(10)) { [unowned self] done in
                    self.sut.deleteDocument(id: docStruct.id) { _ in
                        done()
                    }
                }

                let count = Document.countWithPredicate(self.mainContext,
                                                        NSPredicate(format: "id = %@", docStruct.id as
                                                                        CVarArg))

                expect(count).to(equal(0))
            }
        }

        describe(".create()") {
            it("creates document") {
                let title = self.helper.title()
                let docStruct = self.sut.create(title: title)!
                expect(docStruct.title).to(equal(title))
                let count = Document.countWithPredicate(self.mainContext,
                                                        NSPredicate(format: "id = %@", docStruct.id as CVarArg))

                expect(count).to(equal(1))
            }
        }

        describe(".createAsync()") {
            it("creates document") {
                let title = self.helper.title()

                waitUntil(timeout: .seconds(10)) { [unowned self] done in
                    self.sut.createAsync(title: title) { docStruct in
                        expect(docStruct?.title).to(equal(title))
                        done()
                    }
                }
            }
        }

        describe(".fetchOrCreate()") {
            it("creates the document once") {
                let title = self.helper.title()
                let documentStruct = self.sut.fetchOrCreate(title: title)
                expect(documentStruct?.title).to(equal(title))

                let documentStruct2 = self.sut.fetchOrCreate(title: title)
                expect(documentStruct2?.title).to(equal(title))

                expect(documentStruct?.id).notTo(beNil())
                expect(documentStruct?.id).to(equal(documentStruct2?.id))
            }
        }

        describe(".fetchOrCreateAsync()") {
            it("fetches asynchronisely") {
                let title = self.helper.title()

                waitUntil(timeout: .seconds(10)) { [unowned self] done in
                    self.sut.fetchOrCreateAsync(title: title) { documentStruct in
                        expect(documentStruct?.title).to(equal(title))
                        done()
                    }
                }
            }

            context("with semaphore") {
                it("fetches async") {
                    // Just a simple example showing the use of semaphores to wait for async jobs
                    let semaphore = DispatchSemaphore(value: 0)
                    let title = self.helper.title()

                    self.sut.createAsync(title: title) { documentStruct in
                        XCTAssertEqual(documentStruct?.title, title)
                        semaphore.signal()
                    }

                    semaphore.wait()
                }
            }
        }

        describe(".onDocumentChange()") {
            it("calls handler on document updates") {
                var docStruct = self.helper.createDocumentStruct()
                self.helper.saveLocally(docStruct)

                let newTitle = self.helper.title()

                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(10)) { done in
                    cancellable = self.sut.onDocumentChange(docStruct) { updatedDocStruct in
                        expect(docStruct.id).to(equal(updatedDocStruct.id))
                        expect(updatedDocStruct.title).to(equal(newTitle))
                        cancellable.cancel() // To avoid a warning
                        done()
                    }

                    docStruct.title = newTitle
                    self.sut.saveDocument(docStruct) { result in
                        expect { try result.get() }.toNot(throwError())
                        expect { try result.get() }.to(beTrue())
                    }
                }
            }

            it("doesn't call handler if beam_api_data only is modified") {
                let docStruct = self.helper.createDocumentStruct()
                self.helper.saveLocally(docStruct)
                let newData = "another data"
                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(10)) { done in
                    cancellable = self.sut.onDocumentChange(docStruct) { updatedDocStruct in
                        expect(docStruct.id).to(equal(updatedDocStruct.id))
                        expect(updatedDocStruct.data).to(equal(newData.asData))
                        expect(updatedDocStruct.previousData).to(equal(newData.asData))
                        cancellable.cancel() // To avoid a warning
                        done()
                    }

                    let document = Document.fetchWithId(self.mainContext, docStruct.id)!
                    document.beam_api_data = newData.asData
                    //swiftlint:disable:next force_try
                    try! self.mainContext.save()

                    // Note: waitUntil fails if done() is called more than once, I use this to trigger
                    // one event and get out of the waitUntil loop.
                    // TL;DR: this will fail if `save()` generates 2 callbacks in `onDocumentChange`
                    document.data = newData.asData
                    //swiftlint:disable:next force_try
                    try! self.mainContext.save()
                }
            }
        }
    }
}
