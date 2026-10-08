import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
class PersistenceTests: QuickSpec {
    override func spec() {
        it("saves a standard value") {
            let previous = Persistence.Authentication.hasAppleCalendarConnection
            Persistence.Authentication.hasAppleCalendarConnection = true
            expect(Persistence.Authentication.hasAppleCalendarConnection) == true
            Persistence.Authentication.hasAppleCalendarConnection = previous
        }

        it("saves a keychain value") {
            let previous = Persistence.Authentication.googleCalendarTokens
            let tokens = ["token": String.randomTitle()]
            Persistence.Authentication.googleCalendarTokens = tokens
            expect(Persistence.Authentication.googleCalendarTokens) == tokens
            Persistence.Authentication.googleCalendarTokens = previous
        }
    }
}
