import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Vinyl

@testable import Beam
@testable import BeamCore

class BeamTestsHelper {
    private var turntable: Turntable?
    var testName: String = "no_test_name"

    func beginNetworkRecording(test: XCTestCase? = nil) {
        // Network recording disabled — API infrastructure removed
    }

    func endNetworkRecording() {
        // Network recording disabled — API infrastructure removed
    }

    static let encoder = JSONEncoder()
    static let decoder = BeamJSONDecoder()

    func disableNetworkRecording() {
        turntable = nil
        BeamURLSession.reset()
    }

    static func login() {
        // Remote auth removed — no-op
    }

    static func logout() {
        // Remote auth removed — no-op
    }
}
