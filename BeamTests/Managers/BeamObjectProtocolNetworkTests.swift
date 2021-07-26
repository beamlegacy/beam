import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import BeamCore

@testable import Beam

class BeamObjectProtocolNetworkTests: QuickSpec {
    override func spec() {
        var sut: BeamObjectManager!
        let beamObjectHelper = BeamObjectTestsHelper()
        let beamHelper = BeamTestsHelper()
        let beforeConfigApiHostname = Configuration.apiHostname

        beforeEach {
            // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
            // back from Vinyl
            BeamDate.freeze("2021-03-19T12:21:03Z")

            APIRequest.networkCallFiles = []

            sut = BeamObjectManager()
            sut.clearNetworkCalls()
            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()

            Configuration.beamObjectAPIEnabled = true

            BeamObjectManager.unRegisterAll()
            MyRemoteObjectManager().registerOnBeamObjectManager()
        }

        afterEach {
            beamHelper.endNetworkRecording()

            sut.clearNetworkCalls()

            Configuration.beamObjectAPIEnabled = EnvironmentVariables.beamObjectAPIEnabled
        }
    }
}
