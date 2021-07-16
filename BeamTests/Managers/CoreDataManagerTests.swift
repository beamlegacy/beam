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
            documentManager = DocumentManager()
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
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == true

                do {
                    try sut.backup(backupURL)
                } catch {
                    fail("failed creating backup: \(error.localizedDescription)")
                }


                // I use this when I need to copy a new backup and know one of the note's title
                /*
                print(backupURL)
                print(docStruct.title)
                 */

                // New note exists, then is deleted
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == true
                helper.deleteAllDocuments()
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == false

                do {
                    try sut.importBackup(backupURL)
                } catch {
                    fail("failed importing backup: \(error.localizedDescription)")
                }

                // New note exists
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == true
            }
        }

        describe(".importBackup(url)") {
            let url = Bundle(for: type(of: self)).url(forResource: "BeamExport", withExtension: "sqlite")!
            let backupStructTitle = "Intelligent Rubber Table UEycai0djEmn6auAdpPTqdXs6IXsSzApZNvszFa9"
            var docStruct: DocumentStruct!
            beforeEach {
                helper.deleteAllDocuments()
                docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
            }

            it("replaces database with existing backup") {
                // New created note exists
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == true
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(backupStructTitle)) == false

                do {
                    try sut.importBackup(url)
                } catch {
                    fail("failed importing backup")
                }

                // New created note disappeared with backup replacement
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == false
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(backupStructTitle)) == true

                // New note are created, backup note still exists
                docStruct = helper.createDocumentStruct()
                docStruct = helper.saveLocally(docStruct)
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(docStruct.title)) == true
                expect(try! Document.fetchAll(sut.mainContext).map { $0.title }.contains(backupStructTitle)) == true
            }
        }
    }
}
