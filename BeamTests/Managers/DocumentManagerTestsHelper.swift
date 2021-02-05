import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Alamofire

@testable import Beam

class DocumentManagerTestsHelper {
    var sut: DocumentManager!
    var coreDataManager: CoreDataManager!
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    init(documentManager: DocumentManager, coreDataManager: CoreDataManager) {
        sut = documentManager
        self.coreDataManager = coreDataManager
    }

    func saveRemotely(_ docStruct: DocumentStruct) {
        waitUntil { done in
            self.sut.saveDocumentStructOnAPI(docStruct) { _ in
                done()
            }
        }
    }

    func saveRemotelyOnly(_ docStruct: DocumentStruct) {
        waitUntil { done in
            self.sut.documentRequest.saveDocument(docStruct.asApiType()) { _ in
                done()
            }
        }
    }

    func fetchOnAPI(_ docStruct: DocumentStruct) -> DocumentAPIType? {
        var documentAPIType: DocumentAPIType?
        waitUntil { done in
            self.sut.documentRequest.fetchDocument(docStruct.uuidString) { result in
                documentAPIType = try? result.get()
                done()
            }
        }

        return documentAPIType
    }

    func login() {
        let accountManager = AccountManager()
        let email = "fabien+test@beamapp.co"
        let password = Configuration.testAccountPassword

        guard !AuthenticationManager.shared.isAuthenticated else { return }

        waitUntil { done in
            accountManager.signIn(email, password) { _ in
                done()
            }
        }
    }

    func logout() {
        guard AuthenticationManager.shared.isAuthenticated else { return }

        AccountManager.logout()
    }

    func deleteDocumentStruct(_ docStruct: DocumentStruct) {
        waitUntil { done in
            self.sut.deleteDocument(id: docStruct.id) { result in
                expect { try result.get() }.toNot(throwError())
                expect { try result.get() }.to(beTrue())
                done()
            }
        }
    }

    private let faker = Faker(locale: "en-US")
    func createDocumentStruct(_ dataString: String? = nil, title titleParam: String? = nil) -> DocumentStruct {
        let dataString = dataString ?? "whatever binary data"

        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(dataString)

        let docStruct = DocumentStruct(id: UUID(),
                                       title: titleParam ?? title(),
                                       createdAt: BeamDate.now,
                                       updatedAt: BeamDate.now,
                                       data: jsonData,
                                       documentType: .note)

        return docStruct
    }

    func title() -> String {
        return faker.zelda.game() + " " + randomString(length: 40)
    }

    func saveLocally(_ docStruct: DocumentStruct) {
        // The call to `saveDocumentStructOnAPI` expect the document to be already saved locally
        waitUntil { done in
            // To force a local save only, while using the standard code
            Configuration.networkEnabled = false
            self.sut.saveDocument(docStruct) { _ in
                Configuration.networkEnabled = true
                done()
            }
        }
    }

    func createLocalAndRemoteVersions(_ ancestor: String,
                                      newLocal: String? = nil,
                                      newRemote: String? = nil) -> DocumentStruct {
        BeamDate.travel(-600)
        var docStruct = self.createDocumentStruct()
        docStruct.data = ancestor.asData
        // Save document locally + remotely
        self.saveLocally(docStruct)
        self.saveRemotely(docStruct)

        if let newLocal = newLocal {
            // Force to locally save an older version of the document
            BeamDate.travel(2)
            docStruct.updatedAt = BeamDate.now
            docStruct.data = newLocal.asData
            docStruct.previousData = ancestor.asData
            self.saveLocally(docStruct)
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

    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
