import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class ConfigurationTests: QuickSpec {
    override func spec() {
        it("has test env") {
            expect(Configuration.env.rawValue).to(equal("test"))
        }

        it("doesn't have sparkle") {
            expect(Configuration.autoUpdate).to(beFalse())
        }

        it("does have sentry") {
            expect(Configuration.sentryEnabled).to(beTrue())
        }
    }
}
