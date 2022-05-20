import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class WebFieldClassifierTests: XCTestCase {
    var classifier: WebFieldClassifier!

    override func setUpWithError() throws {
        self.classifier = WebFieldClassifier()
    }

    func testTaggedFields() throws {
        let inputs = [
            DOMInputElement(
                type: .email,
                beamId: "id-email",
                autocomplete: "email",
                name: "email",
                required: "",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-password",
                autocomplete: "current-password",
                name: "password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-email"))
        XCTAssertTrue(results.activeFields.contains("id-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-email"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUntaggedLoginPasswordFields() throws {
        let inputs = [
            DOMInputElement(
                type: .text,
                beamId: "id-email",
                required: "",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-email"))
        XCTAssertTrue(results.activeFields.contains("id-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-email"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUntaggedEmailPasswordFields() throws {
        let inputs = [
            DOMInputElement(
                type: .email,
                beamId: "id-email",
                required: "",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-email"))
        XCTAssertTrue(results.activeFields.contains("id-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-email"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testUntaggedEmailPasswordFieldsIgnoringAutocompleteOff() throws {
        let inputs = [
            DOMInputElement(
                type: .email,
                beamId: "id-email",
                required: "",
                visible: true
            ),
            DOMInputElement(
                type: .text,
                beamId: "id-ignore",
                autocomplete: "off",
                required: "",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-email"))
        XCTAssertTrue(results.activeFields.contains("id-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-email"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testOneUntaggedPasswordField() throws {
        let inputs = [
            DOMInputElement(
                type: .password,
                beamId: "id-password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-password"))
        XCTAssertEqual(results.activeFields.count, 1)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 1)

        let group = results.autofillGroups["id-password"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .login)
        XCTAssertEqual(group!.relatedFields.count, 1)
    }

    func testTwoUntaggedPasswordFields() throws {
        let inputs = [
            DOMInputElement(
                type: .password,
                beamId: "id-password1",
                required: "",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-password2",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-password1"))
        XCTAssertTrue(results.activeFields.contains("id-password2"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-password1"))
        XCTAssertTrue(ids.contains("id-password2"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-password1"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group!.action, .createAccount)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testSpotifyLogin() throws {
        let inputs = [
            DOMInputElement(
                type: .text,
                beamId: "id-login-username",
                autocomplete: "off",
                autofocus: "autofocus",
                name: "username",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-login-password",
                autocomplete: "off",
                name: "password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "accounts.spotify.com")

        XCTAssertTrue(results.activeFields.contains("id-login-username"))
        XCTAssertTrue(results.activeFields.contains("id-login-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-login-username"))
        XCTAssertTrue(ids.contains("id-login-password"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-login-password"]
        XCTAssertNotNil(group)
        XCTAssertTrue(group!.isAmbiguous)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testMetallicaLogin() throws {
        let inputs = [
            DOMInputElement(
                type: .text,
                beamId: "id-unrelated",
                autocomplete: "off",
                name: "unrelated",
                visible: true
            ),
            DOMInputElement(
                type: .text,
                beamId: "id-login-username",
                name: "username",
                visible: true
            ),
            DOMInputElement(
                type: .password,
                beamId: "id-login-password",
                autocomplete: "off",
                name: "password",
                required: "",
                visible: true
            )
        ]

        let results = classifier.classify(rawFields: inputs, on: "metallica.com")

        XCTAssertTrue(results.activeFields.contains("id-login-username"))
        XCTAssertTrue(results.activeFields.contains("id-login-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-login-username"))
        XCTAssertTrue(ids.contains("id-login-password"))
        XCTAssertEqual(ids.count, 2)

        let group = results.autofillGroups["id-login-password"]
        XCTAssertNotNil(group)
        XCTAssertTrue(group!.isAmbiguous)
        XCTAssertEqual(group!.relatedFields.count, 2)
    }

    func testInvisibleFieldsAreIgnored() throws {
        let inputs = [
            DOMInputElement(type: .text, beamId: "id-login-1", visible: true),
            DOMInputElement(type: .text, beamId: "id-login-2", visible: false),
            DOMInputElement(type: .password, beamId: "id-password-1", visible: true),
            DOMInputElement(type: .password, beamId: "id-password-2", visible: false),
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-login-1"))
        XCTAssertTrue(results.activeFields.contains("id-password-1"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-login-1"))
        XCTAssertTrue(ids.contains("id-password-1"))
        XCTAssertEqual(ids.count, 2)

        let group = try XCTUnwrap(results.autofillGroups["id-login-1"])
        XCTAssertTrue(group.isAmbiguous)
        XCTAssertEqual(group.relatedFields.count, 2)
        XCTAssertTrue(group.relatedFields.contains { $0.id == "id-login-1" })
        XCTAssertTrue(group.relatedFields.contains { $0.id == "id-password-1" })
    }

    func testMultiplePasswordFields() throws {
        let inputs = [
            DOMInputElement(type: .text, beamId: "id-login-1", visible: true),
            DOMInputElement(type: .text, beamId: "id-login-2", visible: false),
            DOMInputElement(type: .password, beamId: "id-password-1", visible: true),
            DOMInputElement(type: .password, beamId: "id-password-2", visible: true),
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertTrue(results.activeFields.contains("id-login-1"))
        XCTAssertTrue(results.activeFields.contains("id-password-1"))
        XCTAssertTrue(results.activeFields.contains("id-password-2"))
        XCTAssertEqual(results.activeFields.count, 3)

        let ids = results.allInputFieldIds
        XCTAssertTrue(ids.contains("id-login-1"))
        XCTAssertTrue(ids.contains("id-password-1"))
        XCTAssertTrue(ids.contains("id-password-2"))
        XCTAssertEqual(ids.count, 3)

        let loginGroup = try XCTUnwrap(results.autofillGroups["id-login-1"])
        XCTAssertTrue(loginGroup.isAmbiguous)
        XCTAssertEqual(loginGroup.relatedFields.count, 3)
        XCTAssertTrue(loginGroup.relatedFields.contains { $0.id == "id-login-1" })
        XCTAssertTrue(loginGroup.relatedFields.contains { $0.id == "id-password-1" })
        XCTAssertTrue(loginGroup.relatedFields.contains { $0.id == "id-password-2" })

        let passwordGroup1 = try XCTUnwrap(results.autofillGroups["id-password-1"])
        XCTAssertTrue(passwordGroup1.isAmbiguous)
        XCTAssertEqual(passwordGroup1.relatedFields.count, 3)
        XCTAssertTrue(passwordGroup1.relatedFields.contains { $0.id == "id-login-1" })
        XCTAssertTrue(passwordGroup1.relatedFields.contains { $0.id == "id-password-1" })
        XCTAssertTrue(passwordGroup1.relatedFields.contains { $0.id == "id-password-2" })

        let passwordGroup2 = try XCTUnwrap(results.autofillGroups["id-password-2"])
        XCTAssertTrue(passwordGroup2.isAmbiguous)
        XCTAssertEqual(passwordGroup2.relatedFields.count, 3)
        XCTAssertTrue(passwordGroup2.relatedFields.contains { $0.id == "id-login-1" })
        XCTAssertTrue(passwordGroup2.relatedFields.contains { $0.id == "id-password-1" })
        XCTAssertTrue(passwordGroup2.relatedFields.contains { $0.id == "id-password-2" })
    }

    func testMultipleTextFields() throws {
        let inputs = [
            DOMInputElement(type: .text, beamId: "id-login-1", autocomplete: "email", visible: true),
            DOMInputElement(type: .text, beamId: "id-login-2", autocomplete: "username", visible: true),
            DOMInputElement(type: .password, beamId: "id-password-1", autocomplete: "current-password", visible: true),
            DOMInputElement(type: .password, beamId: "id-password-2", visible: false),
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertFalse(results.activeFields.contains("id-login-1")) // ignored because page contains another field with autocomplete=username
        XCTAssertTrue(results.activeFields.contains("id-login-2"))
        XCTAssertTrue(results.activeFields.contains("id-password-1"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertFalse(ids.contains("id-login-1")) // ignored because page contains another field with autocomplete=username
        XCTAssertTrue(ids.contains("id-login-2"))
        XCTAssertTrue(ids.contains("id-password-1"))
        XCTAssertEqual(ids.count, 2)

        XCTAssertNil(results.autofillGroups["id-login-1"])

        let loginGroup2 = try XCTUnwrap(results.autofillGroups["id-login-2"])
        XCTAssertFalse(loginGroup2.isAmbiguous)
        XCTAssertEqual(loginGroup2.relatedFields.count, 2)
        XCTAssertTrue(loginGroup2.relatedFields.contains { $0.id == "id-login-2" })
        XCTAssertTrue(loginGroup2.relatedFields.contains { $0.id == "id-password-1" })

        let passwordGroup1 = try XCTUnwrap(results.autofillGroups["id-password-1"])
        XCTAssertFalse(passwordGroup1.isAmbiguous)
        XCTAssertEqual(passwordGroup1.relatedFields.count, 2)
        XCTAssertTrue(passwordGroup1.relatedFields.contains { $0.id == "id-login-2" })
        XCTAssertTrue(passwordGroup1.relatedFields.contains { $0.id == "id-password-1" })
    }

    /// From ebay.com signup
    func testMultipleTextFieldsWithSameAutocomplete() throws {
        let inputs = [
            DOMInputElement(type: .text, beamId: "id-firstname", autocomplete: "on", name: "firstname", visible: true),
            DOMInputElement(type: .text, beamId: "id-lastname", autocomplete: "on", name: "lastname", visible: true),
            DOMInputElement(type: .text, beamId: "id-email", autocomplete: "on", name: "email", visible: true),
            DOMInputElement(type: .password, beamId: "id-password", autocomplete: "off", name: "password", visible: true),
        ]

        let results = classifier.classify(rawFields: inputs, on: "example.com")

        XCTAssertFalse(results.activeFields.contains("id-firstname")) // ignored because page contains another field with higher score
        XCTAssertFalse(results.activeFields.contains("id-firstname")) // ignored because page contains another field with higher score
        XCTAssertTrue(results.activeFields.contains("id-email"))
        XCTAssertTrue(results.activeFields.contains("id-password"))
        XCTAssertEqual(results.activeFields.count, 2)

        let ids = results.allInputFieldIds
        XCTAssertFalse(ids.contains("id-firstname")) // ignored because page contains another field with higher score
        XCTAssertFalse(ids.contains("id-lastname")) // ignored because page contains another field with higher score
        XCTAssertTrue(ids.contains("id-email"))
        XCTAssertTrue(ids.contains("id-password"))
        XCTAssertEqual(ids.count, 2)

        XCTAssertNil(results.autofillGroups["id-firstname"])
        XCTAssertNil(results.autofillGroups["id-lastname"])

        let loginGroup = try XCTUnwrap(results.autofillGroups["id-email"])
        XCTAssertTrue(loginGroup.isAmbiguous)
        XCTAssertEqual(loginGroup.relatedFields.count, 2)
        XCTAssertTrue(loginGroup.relatedFields.contains { $0.id == "id-email" })
        XCTAssertTrue(loginGroup.relatedFields.contains { $0.id == "id-password" })

        let passwordGroup = try XCTUnwrap(results.autofillGroups["id-password"])
        XCTAssertTrue(passwordGroup.isAmbiguous)
        XCTAssertEqual(passwordGroup.relatedFields.count, 2)
        XCTAssertTrue(passwordGroup.relatedFields.contains { $0.id == "id-email" })
        XCTAssertTrue(passwordGroup.relatedFields.contains { $0.id == "id-password" })
    }
}

fileprivate extension WebFieldClassifier.ClassifierResult {
    var allInputFieldIds: [String] {
        Array(Set(allInputFields.map(\.id)))
    }
}
