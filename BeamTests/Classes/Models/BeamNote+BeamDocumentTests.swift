//
//  BeamNote+BeamDocumentTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 03/06/2022.
//

import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class BeamNote_BeamDocumentTests: QuickSpec, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    override func spec() {
        // swiftlint:disable:next force_try
        var collection: BeamDocumentCollection { BeamData.shared.currentDocumentCollection! }

        let prefix = "My Note"

        beforeEach {
            BeamTestsHelper.logout()
            // swiftlint:disable:next force_try
            try! BeamData.shared.clearAllAccountsAndSetupDefaultAccount()
        }

        afterEach {
            // swiftlint:disable:next force_try
            try! BeamData.shared.clearAllAccountsAndSetupDefaultAccount()
        }

        describe(".availableTitle()") {

            it("returns the prefix if possible") {
                let title = BeamNote.availableTitle(withPrefix: prefix)
                expect(title) == prefix
            }

            it("returns prefix incremented") {
                expect(try collection.fetchOrCreate(self, type: .note(title: prefix))).toNot(throwError())

                let title2 = BeamNote.availableTitle(withPrefix: prefix)
                expect(title2) == prefix + " 2"

                expect(try collection.fetchOrCreate(self, type: .note(title: title2))).toNot(throwError())

                let title3 = BeamNote.availableTitle(withPrefix: prefix)
                expect(title3) == prefix + " 3"

                expect(try collection.fetchOrCreate(self, type: .note(title: title3))).toNot(throwError())

                let title4 = BeamNote.availableTitle(withPrefix: prefix)
                expect(title4) == prefix + " 4"
            }

            it("reuses deleted note title") {
                expect(try collection.fetchOrCreate(self, type: .note(title: prefix))).notTo(throwError())

                let title2 = BeamNote.availableTitle(withPrefix: prefix)
                let doc2 = try collection.fetchOrCreate(self, type: .note(title: title2))

                let title3 = BeamNote.availableTitle(withPrefix: prefix)
                expect(try collection.fetchOrCreate(self, type: .note(title: title3))).toNot(throwError())

                expect(try collection.delete(self, filters: [.id(doc2.id)])).toNot(throwError())

                // title 2 is available again
                let title2Again = BeamNote.availableTitle(withPrefix: prefix)
                expect(title2Again) == prefix + " 2"
            }
        }
    }

}
