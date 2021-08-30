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
            BeamTestsHelper.logout()
            beamHelper.beginNetworkRecording()
            BeamTestsHelper.login()

            Configuration.beamObjectAPIEnabled = true
            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            Configuration.beamObjectAPIEnabled = EnvironmentVariables.beamObjectAPIEnabled
            beamHelper.endNetworkRecording()
        }

        describe("BeamObjects") {
            it("does not leave any beam objects on the API after test calls") {
                let beamRequest = BeamObjectRequest()

                waitUntil(timeout: .seconds(10)) { done in
                    _ = try? beamRequest.fetchAll { result in
                        switch result {
                        case .failure(let error):
                            fail(error.localizedDescription)
                        case .success(let beamObjects):
                            expect(beamObjects).to(haveCount(0))
                            if !beamObjects.isEmpty {
                                fail("Left BeamObjects on the API: \(beamObjects.map { $0.beamObjectType }.joined(separator: ", ")). Please use BeamObjectTestsHelper().delete(objectID) or BeamObjectTestsHelper().deleteAll() after your tests")
                                dump(beamObjects)
                            }
                        }

                        done()
                    }
                }
            }
        }
    }
}
