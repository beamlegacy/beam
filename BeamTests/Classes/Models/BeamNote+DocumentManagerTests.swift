//
//  BeamNote_DocumentManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/02/2022.
//

import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class BeamNote_DocumentManagerTests: QuickSpec {

    override func spec() {

        var helper: DocumentManagerTestsHelper!
        let prefix = "My Note"

        beforeEach {
            helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                                coreDataManager: CoreDataManager.shared)
            BeamTestsHelper.logout()
            helper.deleteAllDocuments()
        }

        afterEach {
            helper.deleteAllDocuments()
        }

        describe(".availableTitle()") {

            it("returns the prefix if possible") {
                let title = BeamNote.availableTitle(withPrefix: prefix)
                expect(title) == prefix
            }

            it("returns prefix incremented") {
                _ = helper.saveLocally(helper.createDocumentStruct(title: prefix))

                let title2 = BeamNote.availableTitle(withPrefix: prefix)
                expect(title2) == prefix + " 2"

                var doc2 = helper.createDocumentStruct(title: title2, id: UUID().uuidString)
                doc2 = helper.saveLocally(doc2)

                let title3 = BeamNote.availableTitle(withPrefix: prefix)
                expect(title3) == prefix + " 3"

                _ = helper.saveLocally(helper.createDocumentStruct(title: title3))

                let title4 = BeamNote.availableTitle(withPrefix: prefix)
                expect(title4) == prefix + " 4"
            }

            it("reuses deleted note title") {
                let _ = helper.saveLocally(helper.createDocumentStruct(title: prefix))

                let title2 = BeamNote.availableTitle(withPrefix: prefix)
                var doc2 = helper.createDocumentStruct(title: title2, id: UUID().uuidString)
                doc2 = helper.saveLocally(doc2)

                let title3 = BeamNote.availableTitle(withPrefix: prefix)
                let _ = helper.saveLocally(helper.createDocumentStruct(title: title3))

                waitUntil(timeout: .seconds(10)) { done in
                    helper.documentManager.softDelete(id: doc2.id) { result in
                        done()
                    }
                }

                // title 2 is available again
                let title2Again = BeamNote.availableTitle(withPrefix: prefix)
                expect(title2Again) == prefix + " 2"
            }
        }

    }

}
