import Foundation
import XCTest
import Quick
import Nimble
@testable import Beam

class BeamUITestsMenuGeneratorTests: QuickSpec {
    var sut: BeamUITestsMenuGenerator = BeamUITestsMenuGenerator()

    override func spec() {
        beforeEach {
            BeamTestsHelper.logout()
        }
        describe(".populateWithJournalNote()") {
            it("is fast") {
                self.sut.executeCommand(.populateDBWithJournal)
            }
        }
    }
}
