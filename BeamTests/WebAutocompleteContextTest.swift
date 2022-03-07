import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class WebAutocompleteContextTest: XCTestCase {
    var webAutocompleteContext: WebAutocompleteContext!

    override func setUpWithError() throws {
        self.webAutocompleteContext = WebAutocompleteContext()
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

        let results = self.webAutocompleteContext.update(with: inputs, on: "example.com")

        XCTAssertTrue(results.contains("id-email"))
        XCTAssertTrue(results.contains("id-password"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-email")
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUpdateWithUntaggedLoginPasswordFields() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.text),
                beamId: "id-email",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            ),
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "example.com")

        XCTAssertTrue(results.contains("id-email"))
        XCTAssertTrue(results.contains("id-password"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-email")
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUpdateWithUntaggedEmailPasswordFields() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.email),
                beamId: "id-email",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            ),
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "example.com")

        XCTAssertTrue(results.contains("id-email"))
        XCTAssertTrue(results.contains("id-password"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-email")
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUpdateWithUntaggedEmailPasswordFieldsIgnoringAutocompleteOff() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.email),
                beamId: "id-email",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            ),
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.text),
                beamId: "id-ignore",
                autocomplete: "off",
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            ),
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "example.com")

        XCTAssertTrue(results.contains("id-email"))
        XCTAssertTrue(results.contains("id-password"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-email")
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUpdateWithOneUntaggedPasswordField() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "example.com")

        XCTAssertTrue(results.contains("id-password"))
        XCTAssertEqual(results.count, 1)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 1)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-password")
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 1)
    }

    func testUpdateWithTwoUntaggedPasswordFields() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password1",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            ),
            Beam.DOMInputElement(
                type: Optional(Beam.DOMInputElementType.password),
                beamId: "id-password2",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: nil,
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "example.com")

        XCTAssertTrue(results.contains("id-password1"))
        XCTAssertTrue(results.contains("id-password2"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-password1"))
        XCTAssertTrue(ids.contains("id-password2"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-password1")
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .createAccount)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUpdateWithSpotifyLogin() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: .text,
                beamId: "id-login-username",
                autocomplete: "off",
                autofocus: "autofocus",
                elementClass: nil,
                name: "username",
                required: nil
            ),
            Beam.DOMInputElement(
                type: .password,
                beamId: "id-login-password",
                autocomplete: "off",
                autofocus: nil,
                elementClass: nil,
                name: "password",
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "accounts.spotify.com")

        XCTAssertTrue(results.contains("id-login-username"))
        XCTAssertTrue(results.contains("id-login-password"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-login-username"))
        XCTAssertTrue(ids.contains("id-login-password"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-login-password")
        XCTAssertNotNil(group)
        XCTAssertTrue(group!.isAmbiguous)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUpdateWithMetallicaLogin() throws {
        let inputs = [
            Beam.DOMInputElement(
                type: .text,
                beamId: "id-unrelated",
                autocomplete: "off",
                autofocus: nil,
                elementClass: nil,
                name: "unrelated",
                required: nil
            ),
            Beam.DOMInputElement(
                type: .text,
                beamId: "id-login-username",
                autocomplete: nil,
                autofocus: nil,
                elementClass: nil,
                name: "username",
                required: nil
            ),
            Beam.DOMInputElement(
                type: .password,
                beamId: "id-login-password",
                autocomplete: "off",
                autofocus: nil,
                elementClass: nil,
                name: "password",
                required: Optional("")
            )
        ]

        let results = self.webAutocompleteContext.update(with: inputs, on: "metallica.com")

        XCTAssertTrue(results.contains("id-login-username"))
        XCTAssertTrue(results.contains("id-login-password"))
        XCTAssertEqual(results.count, 2)

        let ids = self.webAutocompleteContext.allInputFieldIds
        XCTAssertTrue(ids.contains("id-login-username"))
        XCTAssertTrue(ids.contains("id-login-password"))
        XCTAssertEqual(ids.count, 2)

        let group = self.webAutocompleteContext.autocompleteGroup(for: "id-login-password")
        XCTAssertNotNil(group)
        XCTAssertTrue(group!.isAmbiguous)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }
}

fileprivate extension WebAutocompleteContext {
    var allInputFieldIds: [String] {
        Array(Set(allInputFields.map(\.id)))
    }
}
