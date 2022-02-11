import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import CryptoKit

@testable import Beam
@testable import BeamCore

class EncryptionManagerTests: QuickSpec {
    override func spec() {
        let sut = EncryptionManager()
        let text = "✔ \(String.randomTitle()) ✅"
        beforeEach {
            sut.resetPrivateKeys(andMigrateOldSharedKey: false)
        }

        describe("encryptData()") {
            it("generates a longer encrypted string") {
                guard let encryptedData = try sut.encryptData(text.asData, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt data")
                    return
                }

                expect(encryptedData.base64EncodedString().count) >= 100
            }

            it("encrypts") {
                guard let encryptedData = try sut.encryptData(text.asData, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt data")
                    return
                }

                guard let encryptedData2 = try sut.encryptData(text.asData, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt data")
                    return
                }

                expect(encryptedData).toNot(beNil())
                expect(encryptedData) != encryptedData2
                expect(text.asData) != encryptedData
            }
        }

        describe("encryptString()") {
            it("generates a longer encrypted string") {
                guard let encryptedString = try sut.encryptString(text, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt string")
                    return
                }

                expect(encryptedString.count) >= 100
            }

            it("encrypts") {
                guard let encryptedString = try sut.encryptString(text, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt string")
                    return
                }

                guard let encryptedString2 = try sut.encryptString(text, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt string")
                    return
                }

                expect(encryptedString).toNot(beNil())
                expect(encryptedString) != encryptedString2
                expect(text) != encryptedString

                // Used to get new samples
                Logger.shared.logDebug(text, category: .encryption)
                Logger.shared.logDebug(sut.privateKey(for: Configuration.testAccountEmail).asString(), category: .encryption)
                Logger.shared.logDebug(encryptedString, category: .encryption)
            }
        }

        describe("decryptData()") {
            it("decrypts data") {
                guard let encryptedData = try sut.encryptData(text.asData, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't encrypt data")
                    return
                }
                guard let decryptedData = try sut.decryptData(encryptedData, sut.privateKey(for: Configuration.testAccountEmail)) else {
                    fail("Can't decrypt data")
                    return
                }

                expect(text) == decryptedData.asString
            }

            context("using ChaChaPoly") {
                let keyString = "/oRhk2rBHS1/P7qK0Hu3s3HTZSlHZyw6kHxwzuqB88I="
                let encryptedString = "kgm0JIcnycUQgRFidnEGMoMJFCkT+Y4WVK3SIhVGQjlFwJu7Wu9ZBDbH1nwKI+oVjY+jbyT9PPV2nKlLMemglR9NnkY9cN6QO9KaxbRong5qB1ahBU6jY++0rIs="
                let clearText = "Ergonomic Cotton Gloves Jj7rvg9rigKdl9XfWKp8FdfcjExxmOzitrzz0NUT"
                it("decrypts previously encrypted data") {
                    let key = SymmetricKey(base64EncodedString: keyString)

                    guard let encryptedData = Data(base64Encoded: encryptedString),
                          let decryptedData = try sut.decryptData(encryptedData,
                                                                  key,
                                                                  using: EncryptionManager.Algorithm.ChaChaPoly) else {
                        fail("Should not happen")
                        return
                    }

                    expect(clearText) == decryptedData.asString
                }
            }

            context("Using AES GCM") {
                let keyString = "g77d4Ulrd7jfUJeKEXTQDU5JMd2FlIRbjm3N/o3pAeI="
                let encryptedString = "6ykpONKB2A8zXqNbjpSTURkwpGHQgR2mF3fv+l8Jc5MNfFIm1CeaUuUad9U5PXP40mTXGazQCLQ/Xkq4efWEfRpezPZL2c8tJlBNYLuOtgyoJFGprr/cE9fltey4fUBVUWoSwCZ5yA=="
                let clearText = "✔ Ergonomic Granite Computer 7svhQcDlj4LraUa9BuC2p9Ek5OagBet2JpptTbls ✅"
                it("decrypts previously encrypted data") {
                    let key = SymmetricKey(base64EncodedString: keyString)

                    guard let encryptedData = Data(base64Encoded: encryptedString),
                          let decryptedData = try sut.decryptData(encryptedData,
                                                                  key,
                                                                  using: EncryptionManager.Algorithm.AES_GCM) else {
                        fail("Should not happen")
                        return
                    }

                    expect(clearText) == decryptedData.asString
                }
            }
        }

        describe("privateKey()") {
            let key1 = sut.privateKey(for: Configuration.testAccountEmail)
            let key2 = sut.privateKey(for: Configuration.testAccountEmail)

            it("gives the same key") {
                expect(key1) == key2
            }
        }

        describe("generateKey()") {
            it("generates a key") {
                let key1 = sut.generateKey()
                let key2 = sut.generateKey()
                expect(key1) != key2
            }
        }

        describe("serialize") {
            let symmetricKey = SymmetricKey(size: .bits256)

            it("serializes key as String") {
                let serializedSymmetricKey = symmetricKey.asString()

                guard let deserializedSymmetricKey = SymmetricKey(base64EncodedString: serializedSymmetricKey) else {
                    fail("deserializedSymmetricKey was nil.")
                    return
                }

                expect(symmetricKey) == deserializedSymmetricKey
            }
        }

        describe("Password derived keys") {
            let password = "my password"

            it("has the same private keys") {
                var key = SymmetricKey(data: SHA256.hash(data: password.asData))
                var key2 = SymmetricKey(data: SHA256.hash(data: password.asData))

                expect(key) == key2

                key = SymmetricKey(data: SHA512.hash(data: password.asData))
                key2 = SymmetricKey(data: SHA512.hash(data: password.asData))
            }
        }
    }
}
