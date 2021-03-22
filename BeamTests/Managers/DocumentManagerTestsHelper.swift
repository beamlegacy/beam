import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam

class DocumentManagerTestsHelper {
    var documentManager: DocumentManager!
    var coreDataManager: CoreDataManager!
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    init(documentManager: DocumentManager, coreDataManager: CoreDataManager) {
        self.documentManager = documentManager
        self.coreDataManager = coreDataManager
    }

    func deleteAllDocuments() {
        let semaphore = DispatchSemaphore(value: 0)

        documentManager.deleteAllDocuments() { _ in
            semaphore.signal()
        }
        semaphore.wait()
    }

    func saveLocallyAndRemotely(_ docStruct: DocumentStruct) -> DocumentStruct {
        // The call to `saveDocumentStructOnAPI` expect the document to be already saved locally
        var newVersion = docStruct
        waitUntil(timeout: .seconds(10)) { done in
            // To force a local save only, while using the standard code
            newVersion = self.documentManager.saveDocument(docStruct, true, { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }, completion: nil)
        }

        return newVersion
    }

    func saveLocally(_ docStruct: DocumentStruct) -> DocumentStruct {
        // The call to `saveDocumentStructOnAPI` expect the document to be already saved locally
        var newVersion = docStruct
        waitUntil(timeout: .seconds(10)) { done in
            // To force a local save only, while using the standard code
            newVersion = self.documentManager.saveDocument(docStruct, false, completion:  { result in
                expect { try result.get() }.toNot(throwError())
                if case .failure(let error) = result {
                    fail(error.localizedDescription)
                }
                done()
            })
        }

        return newVersion
    }

    func saveRemotely(_ docStruct: DocumentStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            self.documentManager.saveDocumentStructOnAPI(docStruct) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }
    }

    func saveRemotelyOnly(_ docStruct: DocumentStruct) {
        let documentRequest = DocumentRequest()

        waitUntil(timeout: .seconds(10)) { done in
            _ = try? documentRequest.saveDocument(docStruct.asApiType()) { result in
                expect { try result.get() }.toNot(throwError())
                done()
            }
        }
    }

    func fetchOnAPI(_ docStruct: DocumentStruct) -> DocumentAPIType? {
        var documentAPIType: DocumentAPIType?
        let documentRequest = DocumentRequest()

        let semaphore = DispatchSemaphore(value: 0)
        _ = try? documentRequest.fetchDocument(docStruct.uuidString) { result in
            documentAPIType = try? result.get()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        return documentAPIType
    }

    func fetchOnAPIWithLatency(_ docStruct: DocumentStruct, _ newLocal: String) -> Bool {
        for _ in 0...10 {
            let remoteStruct = fetchOnAPI(docStruct)
            expect(remoteStruct?.id).to(equal(docStruct.uuidString))
            if remoteStruct?.data == newLocal {
                return true
            }
            usleep(50)
        }
        return false
    }

    func deleteDocumentStruct(_ docStruct: DocumentStruct) {
        waitUntil(timeout: .seconds(10)) { done in
            self.documentManager.deleteDocument(id: docStruct.id) { result in
                expect { try result.get() }.toNot(throwError())
                expect { try result.get() }.to(beTrue())
                if case .failure(let error) = result {
                    fail(error.localizedDescription)
                }
                if case .success(let success) = result, success == false {
                    fail("Should not happen")
                }
                done()
            }
        }
    }

    private let faker = Faker(locale: "en-US")
    func createDocumentStruct(_ dataString: String? = nil, title titleParam: String? = nil, id: String? = nil) -> DocumentStruct {
        let dataString = dataString ?? "whatever binary data"

        var docStruct = DocumentStruct(id: UUID(),
                                       title: titleParam ?? String.randomTitle(),
                                       createdAt: BeamDate.now,
                                       updatedAt: BeamDate.now,
                                       data: dataString.asData,
                                       documentType: .note,
                                       version: 0)

        if let id = id {
            docStruct.id = UUID(uuidString: id) ?? docStruct.id
        }

        return docStruct
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
        guard let localDocument = Document.fetchWithId(mainContext, docStruct.id) else {
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
}
