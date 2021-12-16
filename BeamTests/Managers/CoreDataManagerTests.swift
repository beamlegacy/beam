import Foundation
import Quick
import Nimble

@testable import Beam
class CoreDataManagerTests: QuickSpec {
    override func spec() {
        var sut: CoreDataManager!
        var documentManager: DocumentManager!
        var helper: DocumentManagerTestsHelper!

        beforeEach {
            sut = CoreDataManager.shared
            documentManager = DocumentManager(coreDataManager: sut)
            helper = DocumentManagerTestsHelper(documentManager: documentManager,
                                                coreDataManager: CoreDataManager.shared)
        }

        it("has SQLite store") {
            expect(sut.persistentContainer.persistentStoreDescriptions.first?.type).to(equal(NSSQLiteStoreType))
        }

        describe("backup") {
            let backupURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("backup.sqlite")

            var docStruct: DocumentStruct!
            beforeEach {
                try? FileManager().removeItem(at: backupURL)
                docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
            }

            it("imports its own backup") {
                // New note exists
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == true

                do {
                    try sut.backup(backupURL)
                } catch {
                    fail("failed creating backup: \(error.localizedDescription)")
                }

                /*
                 Importing a backup changes too much things in the underlying core data code, and we have to recreate
                 objects or else it'll crash.
                 */
                sut = CoreDataManager.shared
                documentManager = DocumentManager(coreDataManager: sut)
                helper = DocumentManagerTestsHelper(documentManager: documentManager,
                                                    coreDataManager: CoreDataManager.shared)

                // I use this when I need to copy a new backup and know one of the note's title
//                print(backupURL)
//                print(docStruct.title)

                // New note exists, then is deleted
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == true
                helper.deleteAllDocuments()
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == false

                do {
                    try sut.importBackup(backupURL)
                } catch {
                    fail("failed importing backup: \(error.localizedDescription)")
                }

                // New note exists
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == true
            }
        }

        describe(".importBackup(url)") {
            let url = Bundle(for: type(of: self)).url(forResource: "BeamExport", withExtension: "sqlite")!
            let backupStructTitle = "Intelligent Wooden Car 3bX5zUnur4JIEozqVsjaqMxOuq8fH4rkH0UG9sTt"
            var docStruct: DocumentStruct!
            beforeEach {
                helper.deleteAllDocuments()
                docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
            }

            it("replaces database with existing backup") {
                // New created note exists
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == true
                expect(try! documentManager.fetchAll().map { $0.title }.contains(backupStructTitle)) == false

                do {
                    try sut.importBackup(url)
                } catch {
                    fail("failed importing backup")
                }

                // New created note disappeared with backup replacement
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == false
                expect(try! documentManager.fetchAll().map { $0.title }.contains(backupStructTitle)) == true

                // New note are created, backup note still exists
                docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
                expect(try! documentManager.fetchAll().map { $0.title }.contains(docStruct.title)) == true
                expect(try! documentManager.fetchAll().map { $0.title }.contains(backupStructTitle)) == true
            }
        }
    }
}
