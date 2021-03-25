import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import CryptoKit

@testable import Beam
class EncryptionManagerTests: QuickSpec {
    override func spec() {
        let sut = EncryptionManager()
        let text = String.randomTitle()
        beforeEach {
            sut.clearPrivateKey()
        }

        describe("encryptData()") {
            it("generates a longer encrypted string") {
                guard let encryptedData = try sut.encryptData(text.asData) else {
                    fail("Can't encrypt data")
                    return
                }

                expect(encryptedData.base64EncodedString().count) >= 100
            }

            it("encrypts") {
                guard let encryptedData = try sut.encryptData(text.asData) else {
                    fail("Can't encrypt data")
                    return
                }

                guard let encryptedData2 = try sut.encryptData(text.asData) else {
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
                guard let encryptedString = try sut.encryptString(text) else {
                    fail("Can't encrypt string")
                    return
                }

                expect(encryptedString.count) >= 100
            }

            it("encrypts") {
                guard let encryptedString = try sut.encryptString(text) else {
                    fail("Can't encrypt string")
                    return
                }

                guard let encryptedString2 = try sut.encryptString(text) else {
                    fail("Can't encrypt string")
                    return
                }

                expect(encryptedString).toNot(beNil())
                expect(encryptedString) != encryptedString2
                expect(text) != encryptedString
            }
        }

        describe("decryptData()") {
            it("decrypts data") {
                guard let encryptedData = try sut.encryptData(text.asData) else {
                    fail("Can't encrypt data")
                    return
                }

                guard let decryptedData = try sut.decryptData(encryptedData) else {
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
                let keyString = "nc0ogib3Ymdink8ys3pf2wuoZTjdQLK0MF3LwAPqP6A="
                let encryptedString = "OMlHyj4XvkfG0hp1rCVzm9dFLN0gR6HPv4r/HRSi6IKFHYQhY4fMlN5/GqRTgxa75wUlasnFa136Hj6hXkrouSyaEvGjqLy8gn27NIpJd3GqDayNLJvE"
                let clearText = "Small Cotton Chair dLRKbPUjmfTmnGNjd0z7iYs6MdWVJNTIOyfactPI"
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
            let key1 = sut.privateKey()
            let key2 = sut.privateKey()

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
