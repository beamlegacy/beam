import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

class DocumentManagerTestsHelper {
    var documentManager: DocumentManager!
    var coreDataManager: CoreDataManager!
    let databaseManager = DatabaseManager()

    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    init(documentManager: DocumentManager, coreDataManager: CoreDataManager) {
        self.documentManager = documentManager
        self.coreDataManager = coreDataManager
    }

    func deleteAllDocuments() {
        let semaphore = DispatchSemaphore(value: 0)

        documentManager.deleteAll { _ in
            semaphore.signal()
        }
        semaphore.wait()
    }

    func deleteAllDatabases() {
        let semaphore = DispatchSemaphore(value: 0)

        databaseManager.deleteAll { _ in
            semaphore.signal()
        }
        semaphore.wait()
    }

    func saveLocallyAndRemotely(_ docStruct: DocumentStruct) -> DocumentStruct {
        var result = docStruct.copy()

        // The call to `saveDocumentStructOnAPI` expect the document to be already saved locally
        waitUntil(timeout: .seconds(10)) { done in
            result.version += 1

            self.documentManager.saveThenSaveOnAPI(result) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }

        return result
    }

    func saveLocally(_ docStruct: DocumentStruct) -> DocumentStruct {
        var result = docStruct.copy()

        // The call to `saveDocumentStructOnAPI` expect the document to be already saved locally
        waitUntil(timeout: .seconds(10)) { done in
            result.version += 1
            
            // To force a local save only, while using the standard code
            self.documentManager.save(result, false, completion: { result in
                expect { try result.get() }.toNot(throwError())
                if case .failure(let error) = result {
                    fail(error.localizedDescription)
                }
                done()
            })
        }

        return result
    }

    func saveRemotely(_ docStruct: DocumentStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            self.documentManager.saveDocumentStructOnAPI(docStruct) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }
    }

    func saveDatabaseRemotely(_ dbStruct: DatabaseStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            _ = try? self.databaseManager.saveOnBeamObjectAPI(dbStruct) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }
    }

    func saveRemotelyOnly(_ docStruct: DocumentStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            _ = try? self.documentManager.saveOnBeamObjectAPI(docStruct) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }
    }

    func fetchOnAPI(_ docStruct: DocumentStruct) -> DocumentStruct? {
        var fetchedDocStruct: DocumentStruct?

        let semaphore = DispatchSemaphore(value: 0)
        _ = try? documentManager.refreshFromBeamObjectAPI(docStruct, true) { result in
            fetchedDocStruct = try? result.get()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        return fetchedDocStruct
    }

    func fetchDatabaseOnAPI(_ dbStruct: DatabaseStruct) -> DatabaseStruct? {
        var fetchedDbStruct: DatabaseStruct?

        let semaphore = DispatchSemaphore(value: 0)
        // TODO: Add a `fetchDatabase` request for faster GET
        _ = try? databaseManager.refreshFromBeamObjectAPI(dbStruct, true) { result in
            fetchedDbStruct = try? result.get()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        return fetchedDbStruct
    }

    func fetchOnAPIWithLatency(_ docStruct: DocumentStruct, _ newLocal: String) -> Bool {
        for _ in 0...10 {
            let remoteStruct = fetchOnAPI(docStruct)
            expect(remoteStruct?.id).to(equal(docStruct.id))
            if remoteStruct?.data == newLocal.asData {
                return true
            }
            usleep(50)
        }
        return false
    }

    func deleteDocumentStruct(_ docStruct: DocumentStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            self.documentManager.delete(id: docStruct.id) { result in
                done()
            }
        }
    }

    func deleteDatabaseStruct(_ dbStruct: DatabaseStruct, includedRemote: Bool = true) {
        waitUntil(timeout: .seconds(10)) { done in
            self.databaseManager.delete(id: dbStruct.id, includedRemote: includedRemote) { result in
                done()
            }
        }
    }

    private let faker = Faker(locale: "en-US")
    func createDocumentStruct(title titleParam: String? = nil,
                              id: String? = nil) -> DocumentStruct {
        var uuid = UUID()
        if let id = id, let newuuid = UUID(uuidString: id) { uuid = newuuid }
        let title = titleParam ?? String.randomTitle()
        return DocumentStruct(id: uuid,
                              databaseId: DatabaseManager.defaultDatabase.id,
                              title: title,
                              createdAt: BeamDate.now,
                              updatedAt: BeamDate.now,
                              data: defaultDataForDocumentStruct(uuid, title),
                              documentType: .note,
                              version: 0)
    }

    func defaultDataForDocumentStruct(_ id: UUID, _ title: String) -> Data {
        // TODO: set creationDate and type properly
        // The bullet ID is hard coded on purpose, as it wouldn't work with Vinyl if random
        "{ \"id\" : \"\(id)\", \"textStats\" : { \"wordsCount\" : 0 }, \"visitedSearchResults\" : [ ], \"sources\" : { \"sources\" : [ ] }, \"type\" : { \"type\" : \"journal\", \"date\" : \"\" }, \"title\" : \"\(title)\", \"searchQueries\" : [ ], \"open\" : true, \"text\" : { \"ranges\" : [ { \"string\" : \"\" } ] }, \"readOnly\" : false, \"children\" : [ { \"readOnly\" : false, \"score\" : 0, \"id\" : \"0324539D-5AD0-4B8D-AE19-05C1DD97B6FC\", \"creationDate\" : 650476092.56825495, \"open\" : true, \"textStats\" : { \"wordsCount\" : 1 }, \"text\" : { \"ranges\" : [ { \"string\" : \"\" } ] } } ], \"score\" : 0, \"creationDate\" : 650476092.05954194 }".asData
    }

    func fillDocumentStructWithStaticText(_ docStruct: DocumentStruct) -> DocumentStruct {
        // TODO: set creationDate and type properly
        // The bullet ID is hard coded on purpose, as it wouldn't work with Vinyl if random
        let data = "{ \"id\" : \"\(docStruct.id)\", \"textStats\" : { \"wordsCount\" : 0 }, \"visitedSearchResults\" : [ ], \"sources\" : { \"sources\" : [ ] }, \"type\" : { \"type\" : \"journal\", \"date\" : \"\" }, \"title\" : \"\(docStruct.title)\", \"searchQueries\" : [ ], \"open\" : true, \"text\" : { \"ranges\" : [ { \"string\" : \"\" } ] }, \"readOnly\" : false, \"children\" : [ { \"readOnly\" : false, \"score\" : 0, \"id\" : \"0324539D-5AD0-4B8D-AE19-05C1DD97B6FC\", \"creationDate\" : 650476092.56825495, \"open\" : true, \"textStats\" : { \"wordsCount\" : 1 }, \"text\" : { \"ranges\" : [ { \"string\" : \"whatever binary data\" } ] } } ], \"score\" : 0, \"creationDate\" : 650476092.05954194 }".asData
        var result = docStruct.copy()
        result.data = data
        return result
    }

    func fillDocumentStructWithRandomText(_ docStruct: DocumentStruct) -> DocumentStruct {
        let fakeNoteGenerator = FakeNoteGenerator(count: 1, journalRatio: 0.0, futureRatio: 0.05)
        fakeNoteGenerator.generateNotes()
        var result = fakeNoteGenerator.notes.first!.documentStruct!
        result.id = docStruct.id
        result.title = docStruct.title
        result.databaseId = docStruct.databaseId
        return result
    }

    func fillDocumentStructWithEmptyText(_ docStruct: DocumentStruct) -> DocumentStruct {
        var result = docStruct.copy()
        result.data = defaultDataForDocumentStruct(docStruct.id, docStruct.title)
        return result
    }

    func createDefaultDatabase(_ id: String? = nil) {
        coreDataManager.mainContext.performAndWait {
            let database = Database.create(title: "Default")
            if let id = id, let uuid = UUID(uuidString: id) {
                database.id = uuid
            }
            try! CoreDataManager.save(coreDataManager.mainContext)
        }
    }

    func createLocalAndRemoteVersions(_ ancestor: String,
                                      newLocal: String? = nil,
                                      newRemote: String? = nil,
                                      _ id: String? = nil,
                                      _ title: String? = nil) throws -> DocumentStruct {
        BeamDate.travel(-600)
        var docStruct = self.createDocumentStruct()
        if let id = id, let uuid = UUID(uuidString: id) {
            docStruct.id = uuid
        }

        docStruct.title = title ?? docStruct.title
        docStruct.data = ancestor.asData
        docStruct = saveLocallyAndRemotely(docStruct)

        // We'll use saveDocumentOnAPI() later, I need to update the result
        // DocumentStruct to add its previousChecksum
        guard let localDocument = try? Document.fetchWithId(mainContext, docStruct.id) else {
            throw DocumentManagerError.localDocumentNotFound
        }
        docStruct.previousChecksum = localDocument.beam_api_checksum
        //


        if let newLocal = newLocal {
            // Force to locally save an older version of the document
            BeamDate.travel(2)
            docStruct.updatedAt = BeamDate.now
            docStruct.data = newLocal.asData
            docStruct.previousData = ancestor.asData
            docStruct = self.saveLocally(docStruct)
        }

        if let newRemote = newRemote {
            // Generates a new version on the API side only
            BeamDate.travel(2)
            var newDocStruct = docStruct.copy()
            newDocStruct.data = newRemote.asData
            newDocStruct.updatedAt.addTimeInterval(2)
            self.saveRemotelyOnly(newDocStruct)
        }

        return docStruct
    }

    func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func defaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: Database
    func createDatabaseStruct(_ id: String? = nil, _ title: String = "DB666") -> DatabaseStruct {
        var databaseStruct = DatabaseStruct(id: UUID(),
                                            title: title,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now)

        if let id = id {
            databaseStruct.id = UUID(uuidString: id) ?? databaseStruct.id
        }

        return databaseStruct
    }

    func saveDatabaseLocally(_ dbStruct: DatabaseStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            self.databaseManager.save(dbStruct, false, completion:  { result in
                expect { try result.get() }.toNot(throwError())
                if case .failure(let error) = result {
                    fail(error.localizedDescription)
                }
                if case .success(let success) = result, success != true {
                    fail("saveDatabaseLocally wasn't true")
                }
                done()
            })
        }
    }
}
