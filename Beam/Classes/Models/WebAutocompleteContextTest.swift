//
//  WebAutocompleteContextTest.swift
//  BeamTests
//
//  Created by Stef Kors on 15/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class WebAutocompleteContextTest: XCTestCase {
    let passwordStoreMock = PasswordStoreMock()
    var webAutocompleteContext: WebAutocompleteContext!

    override func setUpWithError() throws {
        self.webAutocompleteContext = WebAutocompleteContext(passwordStore: passwordStoreMock)
    }

    func testUpdateWithTaggedFields() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.email),
                beamId: "id-email", autocomplete: Optional("email"),
                autofocus: nil,
                elementClass: nil,
                name: Optional("email"), required: Optional("")
            ),
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password",
                autocomplete: Optional("current-password"),
                autofocus: nil,
                elementClass: nil,
                name: Optional("password"),
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs)

        XCTAssertEqual(results, ["id-email", "id-password"])

        let fields = self.webAutocompleteContext.allInputFields
        let ids = fields.map(\.id)
        XCTAssertEqual(ids, ["id-email", "id-password"])
    }
}
