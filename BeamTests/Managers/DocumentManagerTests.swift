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
    // swiftlint:disable:next function_body_length
    override func spec() {
        var sut: DocumentManager!
        var helper: DocumentManagerTestsHelper!
        let mainContext = CoreDataManager.shared.mainContext

        beforeSuite {
            sut = DocumentManager()
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                coreDataManager: CoreDataManager.shared)
            BeamTestsHelper.logout()
        }

        describe(".deleteAllDocuments()") {
            beforeEach {
                let docStruct = helper.createDocumentStruct()
                helper.saveLocally(docStruct)
                let count = Document.countWithPredicate(mainContext)
                expect(count) >= 1
            }

            context("with Foundation") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.deleteAllDocuments(includedRemote: false) { _ in
                            done()
                        }
                    }
                    let count = Document.countWithPredicate(mainContext)
                    expect(count) == 0
                }
            }
            context("with PromiseKit") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.deleteAllDocuments(includedRemote: false)

                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { _ in }
                    }
                    let count = Document.countWithPredicate(mainContext)
                    expect(count) == 0
                }
            }
            context("with Promises") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = sut.deleteAllDocuments(includedRemote: false)

                        promise.then { success in
                            expect(success) == true
                            done()
                        }
                    }
                    let count = Document.countWithPredicate(mainContext)
                    expect(count) == 0
                }
            }
        }

        describe(".saveDocument()") {
            context("with Foundation") {
                it("saves document") {
                    let docStruct = helper.createDocumentStruct()
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.saveDocument(docStruct) { _ in
                            done()
                        }
                    }

                    let count = Document.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                    expect(count) == 1
                }

                it("saves only the last call on coreData") {
                    let docStruct = helper.createDocumentStruct()
                    let before = DocumentManager.savedCount

                    for _ in 0..<5 {
                        sut.saveDocument(docStruct) { _ in }
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.saveDocument(docStruct) { _ in
                            done()
                        }
                    }

                    // Testing `== 1` might sometimes fail because of speed issue. We want to
                    // make sure we don't have all calls and some operations have been cancelled.
                    // 2 sounds like a good number.
                    expect(DocumentManager.savedCount - before) <= 2
                }

                context("with duplicate titles") {
                    it("should raise error") {
                        let docStruct = helper.createDocumentStruct()
                        helper.saveLocally(docStruct)

                        var docStruct2 = helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.saveDocument(docStruct2) { result in
                                expect { try result.get() }.to(throwError())
                                done()
                            }
                        }

                        docStruct2.deletedAt = Date()

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.saveDocument(docStruct2) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }

                        let count = Document.rawCountWithPredicate(mainContext,
                                                                   NSPredicate(format: "title = %@", docStruct.title),
                                                                   onlyNonDeleted: false)
                        expect(count) == 2
                    }
                }
            }

            context("with PromiseKit") {
                it("saves document") {
                    let docStruct = helper.createDocumentStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.saveDocument(docStruct)

                        promise.done { success in
                                expect(success) == true
                                done()
                            }
                            .catch { _ in }
                    }

                    let count = Document.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                    expect(count) == 1
                }

                it("saves only the last call on coreData") {
                    let docStruct = helper.createDocumentStruct()

                    var count = 0
                    let times = 15
                    var error = false
                    for _ in 0..<times {
                        let promise: PromiseKit.Promise<Bool> = sut.saveDocument(docStruct)
                        promise
                            .done { _ in count += 1 }
                            .catch(policy: .allErrors) { _ in
                                error = true
                            }
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.saveDocument(docStruct)

                        promise.done { success in
                            expect(success) == true
                            done()
                        }
                        .catch(policy: .allErrors) {
                            fail("Shouldn't happen: \($0)")
                        }
                    }

                    expect(count) < (times - 1)
                    expect(error) == true
                }

                context("with duplicate titles") {
                    it("should raise error") {
                        let docStruct = helper.createDocumentStruct()
                        helper.saveLocally(docStruct)

                        var docStruct2 = helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.saveDocument(docStruct2)

                            promise.done { _ in }
                                .catch { error in
                                    expect((error as NSError).code) == 1001
                                    done()
                                }
                        }

                        docStruct2.deletedAt = Date()

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.saveDocument(docStruct2)

                            promise.done { success in
                                    expect(success) == true
                                    done()
                                }
                                .catch { _ in }
                        }

                        let count = Document.rawCountWithPredicate(mainContext,
                                                                   NSPredicate(format: "title = %@", docStruct.title),
                                                                   onlyNonDeleted: false)
                        expect(count) == 2
                    }
                }
            }

            context("With Promises") {
                it("saves document") {
                    let docStruct = helper.createDocumentStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = sut.saveDocument(docStruct)

                        promise.then { success in
                                expect(success) == true
                                done()
                            }
                            .catch { _ in }
                    }

                    let count = Document.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                    expect(count) == 1
                }

                it("saves only the last call on coreData") {
                    let docStruct = helper.createDocumentStruct()

                    var count = 0
                    let times = 15
                    var error = false
                    for _ in 0..<times {
                        let promise: Promises.Promise<Bool> = sut.saveDocument(docStruct)
                        promise.then { _ in count += 1 }.catch { _ in error = true }
                    }

                    let promise: Promises.Promise<Bool> = sut.saveDocument(docStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                                expect(success) == true
                                done()
                            }
                            .catch {
                                fail("Shouldn't happen: \($0)")
                            }
                    }

                    expect(count) < (times - 1)
                    expect(error) == true
                }

                context("with duplicate titles") {
                    it("should raise error") {
                        let docStruct = helper.createDocumentStruct()
                        helper.saveLocally(docStruct)

                        var docStruct2 = helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.saveDocument(docStruct2)

                            promise.then { _ in }
                                .catch { error in
                                    expect((error as NSError).code) == 1001
                                    done()
                                }
                        }

                        docStruct2.deletedAt = Date()

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.saveDocument(docStruct2)

                            promise.then { success in
                                    expect(success) == true
                                    done()
                                }
                                .catch { _ in }
                        }

                        let count = Document.rawCountWithPredicate(mainContext,
                                                                   NSPredicate(format: "title = %@", docStruct.title),
                                                                   onlyNonDeleted: false)
                        expect(count) == 2
                    }
                }
            }
        }

        describe(".loadDocumentById()") {
            it("loads document") {
                let docStruct = helper.createDocumentStruct()
                helper.saveLocally(docStruct)

                let document = sut.loadDocumentById(id: docStruct.id)
                expect(document).toNot(beNil())
                expect(document?.title).to(equal(docStruct.title))
                expect(document?.data).to(equal(docStruct.data))
            }
        }

        describe(".loadDocumentByTitle()") {
            it("loads document") {
                let docStruct = helper.createDocumentStruct()
                helper.saveLocally(docStruct)

                let document = sut.loadDocumentByTitle(title: docStruct.title)
                expect(document).toNot(beNil())
                expect(document?.id).to(equal(docStruct.id))
                expect(document?.data).to(equal(docStruct.data))
            }
        }

        describe(".delete()") {
            context("with Foundation") {
                it("deletes document") {
                    let docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.deleteDocument(id: docStruct.id) { _ in
                            done()
                        }
                    }

                    let count = Document.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as
                                                                            CVarArg))

                    expect(count).to(equal(0))
                }
            }
            context("with PromiseKit") {
                it("deletes document") {
                    let docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.deleteDocument(id: docStruct.id)
                        promise
                            .done { _ in done() }
                            .catch { _ in }
                    }

                    let count = Document.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as
                                                                            CVarArg))

                    expect(count).to(equal(0))
                }
            }
            context("with Promises") {
                it("deletes document") {
                    let docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = sut.deleteDocument(id: docStruct.id)
                        promise.then { _ in done() }
                    }

                    let count = Document.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", docStruct.id as
                                                                            CVarArg))

                    expect(count).to(equal(0))
                }
            }
        }

        describe(".create()") {
            it("creates document") {
                let title = String.randomTitle()
                let docStruct = sut.create(title: title)!
                expect(docStruct.title).to(equal(title))
                let count = Document.countWithPredicate(mainContext,
                                                        NSPredicate(format: "id = %@", docStruct.id as CVarArg))

                expect(count).to(equal(1))
            }

            context("With PromiseKit") {
                var title: String!
                beforeEach {
                    title = String.randomTitle()
                }

                it("creates document") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(title: title)
                            .done { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("creates a document and execute the proper thread") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(title: title)
                            .done { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("doesn't create a document") {
                    let docStruct = helper.createDocumentStruct(title: title)
                    helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
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
                    title = String.randomTitle()
                }

                it("creates document") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(title: title)
                            .then { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("creates a document and execute the proper thread") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(title: title)
                            .then { docStruct in
                                sut.backgroundContext.performAndWait {
                                    expect(docStruct.title).to(equal(title))
                                    done()
                                }
                            }
                            .catch { _ in }
                    }
                }

                it("doesn't create a document") {
                    let docStruct = helper.createDocumentStruct(title: title)
                    helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
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
                let title = String.randomTitle()

                waitUntil(timeout: .seconds(10)) { done in
                    sut.createAsync(title: title) { result in
                        expect { try result.get() }.toNot(throwError())
                        expect { try result.get().title }.to(equal(title))
                        done()
                    }
                }
            }
        }

        describe(".fetchOrCreate()") {
            it("creates the document once") {
                let title = String.randomTitle()
                let documentStruct: DocumentStruct? = sut.fetchOrCreate(title: title)
                expect(documentStruct?.title).to(equal(title))

                let documentStruct2: DocumentStruct? = sut.fetchOrCreate(title: title)
                expect(documentStruct2?.title).to(equal(title))

                expect(documentStruct?.id).notTo(beNil())
                expect(documentStruct?.id).to(equal(documentStruct2?.id))
            }
        }

        describe(".fetchOrCreateAsync()") {
            context("with Foundation") {
                it("fetches asynchronisely") {
                    let title = String.randomTitle()

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.fetchOrCreateAsync(title: title) { documentStruct in
                            expect(documentStruct?.title).to(equal(title))
                            done()
                        }
                    }
                }

                context("with semaphore") {
                    it("fetches async") {
                        // Just a simple example showing the use of semaphores to wait for async jobs
                        let semaphore = DispatchSemaphore(value: 0)
                        let title = String.randomTitle()

                        sut.createAsync(title: title) { result in
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
                    let title = String.randomTitle()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<DocumentStruct> = sut.fetchOrCreate(title: title)
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
                    let title = String.randomTitle()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<DocumentStruct> = sut.fetchOrCreate(title: title)
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
                var docStruct = helper.createDocumentStruct()
                helper.saveLocally(docStruct)

                let newTitle = String.randomTitle()

                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(10)) { done in
                    cancellable = sut.onDocumentChange(docStruct) { updatedDocStruct in
                        expect(docStruct.id).to(equal(updatedDocStruct.id))
                        expect(updatedDocStruct.title).to(equal(newTitle))
                        cancellable.cancel() // To avoid a warning
                        done()
                    }

                    docStruct.title = newTitle
                    docStruct.data = newTitle.asData // to force the callback
                    sut.saveDocument(docStruct) { result in
                        expect { try result.get() }.toNot(throwError())
                        expect { try result.get() }.to(beTrue())
                    }
                }
            }

            it("doesn't call handler if beam_api_data only is modified") {
                let docStruct = helper.createDocumentStruct()
                helper.saveLocally(docStruct)
                let newData = "another data"
                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(10)) { done in
                    cancellable = sut.onDocumentChange(docStruct) { updatedDocStruct in
                        expect(docStruct.id).to(equal(updatedDocStruct.id))
                        expect(updatedDocStruct.data).to(equal(newData.asData))
                        expect(updatedDocStruct.previousData).to(equal(newData.asData))
                        cancellable.cancel() // To avoid a warning
                        done()
                    }

                    let document = Document.fetchWithId(mainContext, docStruct.id)!
                    document.beam_api_data = newData.asData
                    //swiftlint:disable:next force_try
                    try! mainContext.save()

                    // Note: waitUntil fails if done() is called more than once, I use this to trigger
                    // one event and get out of the waitUntil loop.
                    // TL;DR: this will fail if `save()` generates 2 callbacks in `onDocumentChange`
                    document.data = newData.asData
                    //swiftlint:disable:next force_try
                    try! mainContext.save()
                }
            }
        }
    }
}
