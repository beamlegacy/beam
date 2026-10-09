import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class ConfigurationTests: QuickSpec {
    override func spec() {
        it("doesn't have sparkle") {
            expect(Configuration.autoUpdate).to(beFalse())
        }
    }
}
