import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

// Funny test name on purpose, to be last to be executed by the test suite
class ZZZTests: QuickSpec {
    override func spec() {
        let beamHelper = BeamTestsHelper()

        beforeEach {
            BeamDate.freeze("2022-04-18T06:00:03Z")

            BeamTestsHelper.logout()
            beamHelper.beginNetworkRecording()
            BeamTestsHelper.login()

            try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
        }

        afterEach {
            beamHelper.endNetworkRecording()
            BeamDate.reset()
            Configuration.reset()
        }

        describe("suite teardown") {
            it("placeholder — remote Beam API removed") {
                expect(true).to(beTrue())
            }
        }
    }
}
