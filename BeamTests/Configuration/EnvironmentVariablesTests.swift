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

            expect(EnvironmentVariables.Oauth.Github.consumerKey) != "$(GITHUB_CONSUMER_KEY)"
            expect(EnvironmentVariables.Oauth.Github.consumerSecret) != "$(GITHUB_CONSUMER_SECRET)"
            expect(EnvironmentVariables.Oauth.Github.callbackURL) != "$(GITHUB_REDIRECT_URL)"

            expect(EnvironmentVariables.Sentry.key) != "$(SENTRY_KEY)"

        }
    }
}
