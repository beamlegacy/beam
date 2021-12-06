import Foundation
import Quick
import Nimble
import Combine
import Promises

@testable import Beam
class CoreDataContextObserverTests: QuickSpec {
    override func spec() {
        var observer: CoreDataContextObserver!
        var documentManager: DocumentManager!
        var helper: DocumentManagerTestsHelper!

        beforeEach {
            documentManager = DocumentManager()
            helper = DocumentManagerTestsHelper(documentManager: documentManager,
                                                coreDataManager: CoreDataManager.shared)
            observer = CoreDataContextObserver()
            BeamTestsHelper.logout()
            helper.deleteAllDocuments()
        }

        func createNDocuments(_ n: Int) {
            for _ in 0..<n {
                _ = helper.saveLocally(helper.createDocumentStruct())
            }
        }

        describe("observer") {
            it("can observe deleted documents") {
                var numberOfPublishes = 0
                var receivedIds: Set<UUID> = []

                _ = helper.saveLocally(helper.createDocumentStruct())
                let doc2 = helper.saveLocally(helper.createDocumentStruct())
                let doc3 = helper.saveLocally(helper.createDocumentStruct())

                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(5)) { done in
                    cancellable = observer
                        .publisher(for: .deletedDocuments)
                        .sink { ids in
                            ids?.forEach { receivedIds.insert($0) }
                            numberOfPublishes += 1
                        }
                    documentManager.delete(document: doc2) { _ in
                        documentManager.delete(document: doc3) { _ in
                            cancellable.cancel()
                            done()
                        }
                    }
                }
                expect(numberOfPublishes) == 2
                expect(receivedIds.contains(doc2.id)) == true
                expect(receivedIds.contains(doc3.id)) == true
            }

            it("can observe inserted documents") {
                var receivedIds: Set<UUID> = []

                let doc1 = helper.createDocumentStruct()
                let doc2 = helper.createDocumentStruct()
                let doc3 = helper.createDocumentStruct()

                var cancellable: AnyCancellable!
                waitUntil(timeout: .seconds(5)) { done in
                    cancellable = observer
                        .publisher(for: .insertedDocuments)
                        .sink { ids in
                            ids?.forEach { receivedIds.insert($0) }
                        }

                    let promises: [Promises.Promise<Bool>] = [
                        documentManager.save(doc1),
                        documentManager.save(doc2),
                        documentManager.save(doc3)
                    ]
                    Promises.all(promises).then { _ in
                        cancellable.cancel()
                        done()
                    }
                }
                expect(receivedIds) == Set([doc1.id, doc2.id, doc3.id])
            }
        }

    }
}
