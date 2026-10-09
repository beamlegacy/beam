import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

import SwiftUI
class EnvironmentVariablesTests: QuickSpec {
    override func spec() {
        it("has all env variables") {
            // To be used the day Swift + Mirror + static works
//            let mirror = Mirror(reflecting: EnvironmentVariables.self)

            // Values are no longer injected at build time: the ones the tests rely on must be set in the file.
            expect(EnvironmentVariables.MockHttpServer.port) > 0

        }
    }
}
