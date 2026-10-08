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

            expect(EnvironmentVariables.Oauth.Google.consumerKey) != "$(GOOGLE_CONSUMER_KEY)"
            expect(EnvironmentVariables.Oauth.Google.consumerSecret) != "$(GOOGLE_CONSUMER_SECRET)"
            expect(EnvironmentVariables.Oauth.Google.callbackURL) != "$(GOOGLE_REDIRECT_URL)"

        }
    }
}
