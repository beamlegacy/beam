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
@testable import BeamCore

// swiftlint:disable:next type_body_length
class DocumentManagerTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        var sut: DocumentManager!
        var helper: DocumentManagerTestsHelper!

        beforeEach {
            sut = DocumentManager()
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                coreDataManager: CoreDataManager.shared)
            BeamTestsHelper.logout()
        }

        afterEach {
            helper.deleteAllDocuments()
        }

        describe(".deleteAllDocuments()") {
            beforeEach {
                var docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
                let count = sut.count()
                expect(count) >= 1
            }

            context("with Foundation") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.deleteAll(includedRemote: false) { _ in
                            done()
                        }
                    }
                    let count = sut.count()
                    if count > 0 {
                        let documentStructs = try sut.fetchAll()
                        dump(documentStructs)

                        fail("Still have documents: \(documentStructs.compactMap { $0.title })")
                    }
                    expect(count) == 0
                }
            }
            context("with PromiseKit") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.deleteAll(includedRemote: false)

                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { _ in }
                    }
                    let count = sut.count()
                    if count > 0 {
                        let documentStructs = try sut.fetchAll()
                        dump(documentStructs)

                        fail("Still have documents: \(documentStructs.compactMap { $0.title })")
                    }
                    expect(count) == 0
                }
            }
            context("with Promises") {
                it("deletes all") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = sut.deleteAll(includedRemote: false)

                        promise.then { success in
                            expect(success) == true
                            done()
                        }
                    }
                    let count = sut.count()
                    if count > 0 {
                        let documentStructs = try sut.fetchAll()
                        dump(documentStructs)

                        fail("Still have documents: \(documentStructs.compactMap { $0.title })")
                    }
                    expect(count) == 0
                }
            }
        }

        describe(".save()") {
            context("with Foundation") {
                it("saves document") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct.version += 1
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.save(docStruct, completion:  { _ in
                            done()
                        })
                    }

                    let count = sut.count(filters: [.id(docStruct.id)])
                    expect(count) == 1

                    /*
                     I had issues with multiple context not propagating changes between them, I use the following
                     lines to ensure it works for basic scenarios.
                     */
                    guard let savedDocStruct = sut.loadById(id: docStruct.id, includeDeleted: false) else {
                        fail("No coredata instance")
                        return
                    }
                    expect(savedDocStruct.data) == docStruct.data

                    guard let cdDocStruct = try? sut.fetchWithId(docStruct.id, includeDeleted: false) else {
                        fail("No coredata instance")
                        return
                    }
                    expect(cdDocStruct.data) == docStruct.data
                    sut.context.refresh(cdDocStruct, mergeChanges: false)
                    expect(cdDocStruct.data) == docStruct.data
                }

                it("saves all calls on coreData") {
                    var docStruct = helper.createDocumentStruct()
                    let before = DocumentManager.savedCount

                    for _ in 0..<5 {
                        docStruct.version += 1
                        sut.save(docStruct, completion: { _ in })
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        docStruct.version += 1
                        sut.save(docStruct, completion: { _ in done() })
                    }

                    // Testing `== 1` might sometimes fail because of speed issue. We want to
                    // make sure we don't have all calls and some operations have been cancelled.
                    // 2 sounds like a good number.
                    expect(DocumentManager.savedCount - before) == 7
                }

                context("with duplicate titles") {
                    it("should raise error") {
                        var docStruct = helper.createDocumentStruct()
                        docStruct = helper.saveLocally(docStruct)

                        var docStruct2 = helper.createDocumentStruct()
                        docStruct2.title = docStruct.title
                        docStruct2.version += 1

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.save(docStruct2, completion: { result in
                                expect { try result.get() }.to(throwError())
                                done()
                            })
                        }

                        docStruct2.deletedAt = BeamDate.now

                        waitUntil(timeout: .seconds(10)) { done in
                            docStruct2.version += 1
                            sut.save(docStruct2, completion: { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            })
                        }

                        let count = sut.count(filters: [.title(docStruct.title), .includeDeleted])
                        expect(count) == 2
                    }
                }
            }

            context("with PromiseKit") {
                it("saves document") {
                    let docStruct = helper.createDocumentStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.save(docStruct)

                        promise.done { success in
                                expect(success) == true
                                done()
                            }
                            .catch { _ in }
                    }

                    let count = sut.count(filters: [.id(docStruct.id)])
                    expect(count) == 1
                }

                it("saves only the last call on coreData") {
                    var docStruct = helper.createDocumentStruct()

                    var count = 0
                    let times = 15
                    var error = false
                    for _ in 0..<times {
                        docStruct.version += 1
                        let promise: PromiseKit.Promise<Bool> = sut.save(docStruct)

                        promise
                            .done { _ in count += 1 }
                            .catch(policy: .allErrors) { _ in
                                error = true
                            }
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        docStruct.version += 1

                        let promise: PromiseKit.Promise<Bool> = sut.save(docStruct)

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
                        var docStruct = helper.createDocumentStruct()
                        docStruct = helper.saveLocally(docStruct)

                        var docStruct2 = helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.save(docStruct2)

                            promise.done { _ in
                                fail("Shouldn't happen")
                                done()
                            }
                            .catch { error in
                                expect((error as NSError).code) == 1001
                                done()
                            }
                        }

                        docStruct2.deletedAt = BeamDate.now

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.save(docStruct2)

                            promise.done { success in
                                    expect(success) == true
                                    done()
                                }
                                .catch { _ in }
                        }

                        let count = sut.count(filters: [.title(docStruct.title), .includeDeleted])
                        expect(count) == 2
                    }
                }
            }

            context("With Promises") {
                it("saves document") {
                    let docStruct = helper.createDocumentStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = sut.save(docStruct)

                        promise.then { success in
                                expect(success) == true
                                done()
                            }
                            .catch { _ in }
                    }

                    let count = sut.count(filters: [.id(docStruct.id)])
                    expect(count) == 1
                }

                it("saves only the last call on coreData") {
                    var docStruct = helper.createDocumentStruct()

                    var count = 0
                    let times = 15
                    var error = false
                    for _ in 0..<times {
                        docStruct.version += 1
                        let promise: Promises.Promise<Bool> = sut.save(docStruct)
                        promise.then { _ in count += 1 }.catch { _ in
                            error = true
                        }
                    }

                    docStruct.version += 1
                    let promise: Promises.Promise<Bool> = sut.save(docStruct)

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
                        var docStruct = helper.createDocumentStruct()
                        docStruct = helper.saveLocally(docStruct)

                        var docStruct2 = helper.createDocumentStruct()
                        docStruct2.title = docStruct.title

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.save(docStruct2)

                            promise.then { _ in
                                fail("Shouldn't happen")
                                done()
                            }
                            .catch { error in
                                expect((error as NSError).code) == 1001
                                done()
                            }
                        }

                        docStruct2.deletedAt = BeamDate.now

                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.save(docStruct2)

                            promise.then { success in
                                    expect(success) == true
                                    done()
                                }
                                .catch { _ in }
                        }

                        let count = sut.count(filters: [.title(docStruct.title), .includeDeleted])
                        expect(count) == 2
                    }
                }
            }
        }

        describe(".loadById()") {
            it("loads document") {
                var docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)

                let document = sut.loadById(id: docStruct.id, includeDeleted: false)
                expect(document).toNot(beNil())
                expect(document?.title).to(equal(docStruct.title))
                expect(document?.data).to(equal(docStruct.data))
            }
        }

        describe(".loadDocumentByTitle()") {
            it("loads document") {
                var docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)

                let document = sut.loadDocumentByTitle(title: docStruct.title)
                expect(document).toNot(beNil())
                expect(document?.id).to(equal(docStruct.id))
                expect(document?.data).to(equal(docStruct.data))
            }
        }

        describe(".delete(id:)") {
            context("with Foundation") {
                it("deletes document") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.delete(document: docStruct) { _ in
                            done()
                        }
                    }

                    let count = sut.count(filters: [.id(docStruct.id)])

                    expect(count).to(equal(0))
                }
            }
            context("with PromiseKit") {
                it("deletes document") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<Bool> = sut.delete(document: docStruct)
                        promise
                            .done { _ in done() }
                            .catch { _ in }
                    }

                    let count = sut.count(filters: [.id(docStruct.id)])

                    expect(count).to(equal(0))
                }
            }
            context("with Promises") {
                it("deletes document") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<Bool> = sut.delete(document: docStruct)
                        promise.then { _ in done() }
                    }

                    let count = sut.count(filters: [.id(docStruct.id)])

                    expect(count).to(equal(0))
                }
            }
        }

        describe(".delete(ids:)") {
            context("with Foundation") {
                it("deletes document") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)

                    var docStruct2 = helper.createDocumentStruct()
                    docStruct2 = helper.saveLocally(docStruct2)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.delete(documents: [docStruct, docStruct2]) { _ in
                            done()
                        }
                    }

                    var count = sut.count(filters: [.id(docStruct.id)])

                    expect(count).to(equal(0))

                    count = sut.count(filters: [.id(docStruct2.id)])

                    expect(count).to(equal(0))
                }
            }
        }

        describe(".softDelete(ids:)") {
            context("with Foundation") {
                it("deletes document") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)

                    var docStruct2 = helper.createDocumentStruct()
                    docStruct2 = helper.saveLocally(docStruct2)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.softDelete(ids: [docStruct.id, docStruct2.id]) { _ in
                            done()
                        }
                    }

                    var count = sut.count(filters: [.id(docStruct.id)])

                    expect(count).to(equal(0))

                    count = sut.count(filters: [.id(docStruct2.id)])

                    expect(count).to(equal(0))

                    var document = try? sut.fetchWithId(docStruct.id, includeDeleted: true)
                    expect(document?.deleted_at).toNot(beNil())

                    document = try? sut.fetchWithId(docStruct2.id, includeDeleted: true)
                    expect(document?.deleted_at).toNot(beNil())
                }
            }
        }

        describe(".softUndelete(ids:)") {
            context("with Foundation") {
                it("brings back soft-deleted documents") {
                    var docStruct = helper.createDocumentStruct()
                    docStruct = helper.saveLocally(docStruct)

                    var docStruct2 = helper.createDocumentStruct()
                    docStruct2 = helper.saveLocally(docStruct2)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.softDelete(ids: [docStruct.id, docStruct2.id], clearData: false) { _ in
                            done()
                        }
                    }

                    var document = try? sut.fetchWithId(docStruct.id, includeDeleted: true)
                    expect(document?.deleted_at).toNot(beNil())

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.softUndelete(ids: [docStruct.id, docStruct2.id]) { _ in
                            done()
                        }
                    }

                    var count = sut.count(filters: [.id(docStruct.id)])
                    expect(count).to(equal(1))
                    count = sut.count(filters: [.id(docStruct2.id)])
                    expect(count).to(equal(1))

                    document = try? sut.fetchWithId(docStruct.id, includeDeleted: false)
                    expect(document?.deleted_at).to(beNil())

                    document = try? sut.fetchWithId(docStruct2.id, includeDeleted: false)
                    expect(document?.deleted_at).to(beNil())
                }
            }
        }

        describe(".create()") {
            it("creates document") {
                let title = String.randomTitle()
                let docStruct = sut.create(title: title, deletedAt: nil)!
                expect(docStruct.title) == title

                let count = sut.count(filters: [.databaseId(docStruct.databaseId), .id(docStruct.id)])

                expect(count) == 1
            }

            it("fails creating document") {
                let title = String.randomTitle()
                _ = sut.create(title: title, deletedAt: nil)!

                let failDocStruct: DocumentStruct? = sut.create(title: title, deletedAt: nil)
                expect(failDocStruct).to(beNil())
            }

            context("With PromiseKit") {
                var title: String!
                beforeEach {
                    title = String.randomTitle()
                }

                it("creates document") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(id: UUID(), title: title)
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
                            .create(id: UUID(), title: title)
                            .done { docStruct in
                                expect(docStruct.title).to(equal(title))
                                done()
                            }
                            .catch { _ in }
                    }
                }

                it("doesn't create a document") {
                    var docStruct = helper.createDocumentStruct(title: title)
                    docStruct = helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(id: UUID(), title: title)
                            .done { docStruct in
                                fail("Shouldn't happen")
                                done()
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
                            .create(id: UUID(), title: title)
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
                            .create(id: UUID(), title: title)
                            .then { docStruct in
                                sut.backgroundQueue.sync {
                                    expect(docStruct.title).to(equal(title))
                                    done()
                                }
                            }
                            .catch { _ in }
                    }
                }

                it("doesn't create a document") {
                    var docStruct = helper.createDocumentStruct(title: title)
                    docStruct = helper.saveLocally(docStruct)
                    waitUntil(timeout: .seconds(10)) { done in
                        sut
                            .create(id: UUID(), title: title)
                            .then { docStruct in
                                fail("Shouldn't happen")
                                done()
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
                    sut.createAsync(id: UUID(), title: title) { result in
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
                let documentStruct: DocumentStruct? = sut.fetchOrCreate(title, deletedAt: nil)
                expect(documentStruct?.title).to(equal(title))

                let documentStruct2: DocumentStruct? = sut.fetchOrCreate(title, deletedAt: nil)
                expect(documentStruct2?.title).to(equal(title))

                expect(documentStruct?.id).toNot(beNil())
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

                        sut.createAsync(id: UUID(), title: title) { result in
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
                docStruct = helper.saveLocally(docStruct)
                docStruct.version += 1

                let newTitle = String.randomTitle()

                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(10)) { done in
                    cancellable = DocumentManager.documentSaved.receive(on: DispatchQueue.main)
                        .sink { updatedDocStruct in
                            guard updatedDocStruct.id == docStruct.id else { return }
                            expect(docStruct.id).to(equal(updatedDocStruct.id))
                            expect(updatedDocStruct.title).to(equal(newTitle))
                            cancellable.cancel() // To avoid a warning
                            done()
                        }
                    docStruct.title = newTitle
                    docStruct.data = newTitle.asData // to force the callback
                    sut.save(docStruct, completion: { result in
                        expect { try result.get() }.toNot(throwError())
                        expect { try result.get() }.to(beTrue())
                    })
                }
            }

            // Disabling this one, I changed the code to call the handler even if the same manager, as sometimes when
            // saving on the API, we have a conflict, fix/merge the document, and need the UI to be updated.
            xit("does not call handler for same document manager") {
                var docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
                docStruct.version += 1

                let newTitle = String.randomTitle()

                let callbackDocumentManager = DocumentManager()

                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(10)) { done in
                    cancellable = DocumentManager.documentSaved.receive(on: DispatchQueue.main)
                        .sink { updatedDocStruct in
                        expect(docStruct.id).to(equal(updatedDocStruct.id))
                        expect(updatedDocStruct.title).to(equal(newTitle))
                        cancellable.cancel() // To avoid a warning
                        done()
                    }

                    // This should not generate handler callback
                    callbackDocumentManager.save(docStruct, completion: { _ in })

                    docStruct.version += 1
                    docStruct.title = newTitle
                    docStruct.data = newTitle.asData

                    // This will
                    sut.save(docStruct, completion: { result in
                        expect { try result.get() }.toNot(throwError())
                        expect { try result.get() }.to(beTrue())
                    })

                    // done() can only be called once, if twice it will raise error
                }
            }
        }

        describe("document.version") {
            var docStruct: DocumentStruct!

            it("sets document version at creation and after a save") {
                let title = String.randomTitle()

                //swiftlint:disable:next force_cast
                docStruct = sut.create(title: title, deletedAt: nil)!
                expect(docStruct.version).to(equal(0))
                let document = "whatever binary data"
                //swiftlint:disable:next force_try
                let jsonData = try! JSONEncoder().encode(document)
                docStruct.data = jsonData

                // Semaphore is needed or the afterEach deleteDocument might be called *before* this saveDocument is finished
                let semaphore = DispatchSemaphore(value: 0)
                docStruct.version += 1
                sut.save(docStruct, completion: { _ in
                    semaphore.signal()
                })
                semaphore.wait()

                expect(docStruct.version).to(equal(1))
            }

            it("increments the version number for each save operations") {
                let document = "whatever binary data"
                let title = String.randomTitle()

                //swiftlint:disable:next force_try
                let jsonData = try! JSONEncoder().encode(document)

                docStruct = DocumentStruct(id: UUID(),
                                           databaseId: UUID(),
                                           title: title,
                                           createdAt: BeamDate.now,
                                           updatedAt: BeamDate.now,
                                           data: jsonData,
                                           documentType: .note,
                                           version: 0)

                waitUntil(timeout: .seconds(2)) { done in
                    docStruct.version += 1
                    sut.save(docStruct, completion:  { _ in
                        done()
                    })
                    // This is done by BeamNote (the caller), it saves the returned version
                    // and use it when saving again
                    expect(docStruct.version).to(equal(1))
                }

                waitUntil(timeout: .seconds(2)) { done in
                    docStruct.version += 1
                    sut.save(docStruct, completion:  { _ in
                        done()
                    })
                    expect(docStruct.version).to(equal(2))
                }
            }

            it("refuses to save in case of version mismatch") {
                let title = String.randomTitle()

                //swiftlint:disable:next force_cast
                docStruct = sut.create(title: title, deletedAt: nil)!
                expect(docStruct.version).to(equal(0))

                let document = "whatever binary data"
                //swiftlint:disable:next force_try
                let jsonData = try! JSONEncoder().encode(document)
                docStruct.data = jsonData

                for index in 0...3 {
                    waitUntil(timeout: .seconds(2)) { done in
                        docStruct.version += 1

                        sut.save(docStruct, completion:  { _ in
                            done()
                        })
                        // This is done by BeamNote (the caller), it saves the returned version
                        // and use it when saving again
                        let expected: Int64 = 1 + Int64(index)
                        expect(docStruct.version).to(equal(expected))
                    }
                }

                // Try to save a previous version
                docStruct.version = 1
                waitUntil(timeout: .seconds(2)) { done in
                    docStruct.version += 1

                    sut.save(docStruct, completion:  { result in
                        expect { try result.get() }.to(throwError { (error: NSError) in
                            expect(error.code).to(equal(1002))
                        })
                        done()
                    })
                    // TODO: shouldn't increment version
                    expect(docStruct.version).to(equal(2))
                }
            }
        }
    }

}
