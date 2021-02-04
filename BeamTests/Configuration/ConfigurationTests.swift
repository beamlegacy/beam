import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Alamofire

@testable import Beam
class ConfigurationTests: QuickSpec {
    override func spec() {
        it("has test env") {
            expect(Configuration.env).to(equal("test"))
        }

        it("doesn't have sparkle") {
            expect(Configuration.sparkleUpdate).to(beFalse())
        }

        it("doesn't have sentry") {
            expect(Configuration.sentryEnabled).to(beFalse())
        }
    }
}
