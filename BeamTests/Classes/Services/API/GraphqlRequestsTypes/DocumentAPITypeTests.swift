import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
class DocumentAPITypeTests: QuickSpec {
    override func spec() {
        let text = "whatever binary data"
        let apiStruct = DocumentAPIType(id: "whatever")

        beforeEach {
            Configuration.encryptionEnabled = true
            EncryptionManager.shared.clearPrivateKey()
            apiStruct.data = text
        }
        afterEach { Configuration.encryptionEnabled = false }

        describe(".decrypt()") {
            it("works with clear text") {
                expect { try apiStruct.decrypt() }.toNot(throwError())

                expect(apiStruct.data) == text
                expect(apiStruct.encryptedData).to(beNil())
            }
        }

        describe(".encrypt()") {
            it("encrypts the clear text") {
                expect { try apiStruct.encrypt() }.toNot(throwError())

                expect(apiStruct.data) == text
                expect(apiStruct.encryptedData).toNot(beNil())
            }

            it("adds checksum") {
                expect { try apiStruct.encrypt() }.toNot(throwError())
                expect(apiStruct.dataChecksum).toNot(beNil())
            }
        }
    }
}
