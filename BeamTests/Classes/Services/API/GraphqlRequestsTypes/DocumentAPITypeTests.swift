import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
class DocumentAPITypeTests: QuickSpec {
    override func spec() {
        let text = "whatever binary data"
        let sut = DocumentAPIType(id: "whatever")

        context("with encryption") {
            beforeEach {
                Configuration.encryptionEnabled = true
                EncryptionManager.shared.clearPrivateKey()
                sut.data = text
            }
            afterEach { Configuration.encryptionEnabled = false }

            describe(".decrypt()") {
                it("works with clear text") {
                    expect { try sut.decrypt() }.toNot(throwError())

                    expect(sut.data) == text
                    expect(sut.encryptedData).to(beNil())
                }
            }

            describe(".encrypt()") {
                it("encrypts the clear text") {
                    expect { try sut.encrypt() }.toNot(throwError())

                    expect(sut.data) == text
                    expect(sut.encryptedData).toNot(beNil())
                }

                it("adds checksum") {
                    expect { try sut.encrypt() }.toNot(throwError())
                    expect(sut.dataChecksum).toNot(beNil())
                }
            }

            describe(".shouldEncrypt") {
                context("when document is public") {
                    beforeEach { sut.isPublic = true }

                    it("return false") {
                        expect(sut.shouldEncrypt) == false
                    }
                }

                context("when document is private") {
                    beforeEach { sut.isPublic = false }

                    it("return true") {
                        expect(sut.shouldEncrypt) == true
                    }
                }
            }
        }
    }
}
