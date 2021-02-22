// swiftlint:disable file_length

import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import PromiseKit
import Promises

@testable import Beam
// swiftlint:disable:next type_body_length
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
            BeamTestsHelper.logout()
        }

        describe(".deleteAllDocuments()") {
            beforeEach {
                let docStruct = self.helper.createDocumentStruct()
                self.helper.saveLocally(docStruct)
                let count = Document.countWithPredicate(self.mainContext)
                expect(count) >= 1
            }

            context("with Foundation") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.deleteAllDocuments(includedRemote: false) { _ in
                            done()
                        }
                    }
                    let count = Document.countWithPredicate(self.mainContext)
                    expect(count) == 0
                }
            }
            context("with PromiseKit") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = self.sut.deleteAllDocuments(includedRemote: false)

                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { _ in }
                    }
                    let count = Document.countWithPredicate(self.mainContext)
                    expect(count) == 0
                }
            }
            context("with Promises") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = self.sut.deleteAllDocuments(includedRemote: false)

                        promise.then { success in
                            expect(success) == true
                            done()
                        }
                    }
                    let count = Document.countWithPredicate(self.mainContext)
                    expect(count) == 0
                }
            }
        }

        describe(".saveDocument()") {
            context("with Foundation") {
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

            context("with PromiseKit") {
                it("saves document") {
                    let docStruct = self.helper.createDocumentStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = self.sut.saveDocument(docStruct)

                        promise.done { success in
                                expect(success) == true
                                done()
                            }
                            .catch { _ in }
                    }

                    let count = Document.countWithPredicate(self.mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                    expect(count) == 1
                }

                context("with duplicate titles") {
                    it("should raise error") {
                        let docStruct = self.helper.createDocumentStruct()
                        self.helper.saveLocally(docStruct)

                        var docStruct2 = self.helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = self.sut.saveDocument(docStruct2)

                            promise.done { _ in }
                                .catch { error in
                                    expect((error as NSError).code) == 1001
                                    done()
                                }
                        }

                        docStruct2.deletedAt = Date()

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = self.sut.saveDocument(docStruct2)

                            promise.done { success in
                                    expect(success) == true
                                    done()
                                }
                                .catch { _ in }
                        }

                        let count = Document.rawCountWithPredicate(self.mainContext,
                                                                   NSPredicate(format: "title = %@", docStruct.title),
                                                                   onlyNonDeleted: false)
                        expect(count) == 2
                    }
                }
            }

            context("With Promises") {
                it("saves document") {
                    let docStruct = self.helper.createDocumentStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = self.sut.saveDocument(docStruct)

                        promise.then { success in
                                expect(success) == true
                                done()
                            }
                            .catch { _ in }
                    }

                    let count = Document.countWithPredicate(self.mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                    expect(count) == 1
                }

                context("with duplicate titles") {
                    it("should raise error") {
                        let docStruct = self.helper.createDocumentStruct()
                        self.helper.saveLocally(docStruct)

                        var docStruct2 = self.helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = self.sut.saveDocument(docStruct2)

                            promise.then { _ in }
                                .catch { error in
                                    expect((error as NSError).code) == 1001
                                    done()
                                }
                        }

                        docStruct2.deletedAt = Date()

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = self.sut.saveDocument(docStruct2)

                            promise.then { success in
                                    expect(success) == true
                                    done()
                                }
                                .catch { _ in }
                        }

                        let count = Document.rawCountWithPredicate(self.mainContext,
                                                                   NSPredicate(format: "title = %@", docStruct.title),
                                                                   onlyNonDeleted: false)
                        expect(count) == 2
                    }
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
            context("with Foundation") {
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
            context("with PromiseKit") {
                it("deletes document") {
                    let docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = self.sut.deleteDocument(id: docStruct.id)
                        promise
                            .done { _ in done() }
                            .catch { _ in }
                    }

                    let count = Document.countWithPredicate(self.mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as
                                                                            CVarArg))

                    expect(count).to(equal(0))
                }
            }
            context("with Promises") {
                it("deletes document") {
                    let docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = self.sut.deleteDocument(id: docStruct.id)
                        promise.then { _ in done() }
                    }

                    let count = Document.countWithPredicate(self.mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as
                                                                            CVarArg))

                    expect(count).to(equal(0))
                }
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

            context("With PromiseKit") {
                var title: String!
                beforeEach {
                    title = self.helper.title()
                }

                it("creates document") {
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut
                            .create(title: title)
                            .done { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("creates a document and execute the proper thread") {
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut
                            .create(title: title)
                            .done { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("doesn't create a document") {
                    let docStruct = self.helper.createDocumentStruct(title: title)
                    self.helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut
                            .create(title: title)
                            .done { docStruct in
                                expect(docStruct.title).to(equal(title))
                            }
                            .catch { error in
                                expect((error as NSError).code).to(equal(1001))
                                done()
                            }
                    }
                }
            }

            context("With Promises") {
                var title: String!
                beforeEach {
                    title = self.helper.title()
                }

                it("creates document") {
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut
                            .create(title: title)
                            .then { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("creates a document and execute the proper thread") {
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut
                            .create(title: title)
                            .then { docStruct in
                                self.sut.backgroundContext.performAndWait {
                                    expect(docStruct.title).to(equal(title))
                                    done()
                                }
                            }
                            .catch { _ in }
                    }
                }

                it("doesn't create a document") {
                    let docStruct = self.helper.createDocumentStruct(title: title)
                    self.helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        self.sut
                            .create(title: title)
                            .then { docStruct in
                                expect(docStruct.title).to(equal(title))
                            }
                            .catch { error in
                                expect((error as NSError).code).to(equal(1001))
                                done()
                            }
                    }
                }
            }
        }

        describe(".createAsync()") {
            it("creates document") {
                let title = self.helper.title()

                waitUntil(timeout: .seconds(10)) { [unowned self] done in
                    self.sut.createAsync(title: title) { result in
                        expect { try result.get() }.toNot(throwError())
                        expect { try result.get().title }.to(equal(title))
                        done()
                    }
                }
            }
        }

        describe(".fetchOrCreate()") {
            it("creates the document once") {
                let title = self.helper.title()
                let documentStruct: DocumentStruct? = self.sut.fetchOrCreate(title: title)
                expect(documentStruct?.title).to(equal(title))

                let documentStruct2: DocumentStruct? = self.sut.fetchOrCreate(title: title)
                expect(documentStruct2?.title).to(equal(title))

                expect(documentStruct?.id).notTo(beNil())
                expect(documentStruct?.id).to(equal(documentStruct2?.id))
            }
        }

        describe(".fetchOrCreateAsync()") {
            context("with Foundation") {
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

                        self.sut.createAsync(title: title) { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get().title }.to(equal(title))
                            semaphore.signal()
                        }

                        semaphore.wait()
                    }
                }
            }

            context("with PromiseKit") {
                it("fetches asynchronisely") {
                    let title = self.helper.title()

                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        let promise: PromiseKit.Promise<DocumentStruct> = self.sut.fetchOrCreate(title: title)
                        promise
                            .done { docStruct in
                                expect(docStruct.title) == title
                                done()
                            }
                            .catch { _ in }
                    }
                }
            }

            context("with Promises") {
                it("fetches asynchronisely") {
                    let title = self.helper.title()

                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        let promise: Promises.Promise<DocumentStruct> = self.sut.fetchOrCreate(title: title)
                        promise
                            .then { docStruct in
                                expect(docStruct.title) == title
                                done()
                            }
                            .catch { _ in }
                    }
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
