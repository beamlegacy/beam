import Foundation
import XCTest
import Quick
import Nimble
import Combine

@testable import Beam

class SearchEngineAutocompleterTests: QuickSpec {
    override func spec() {
        var scope = Set<AnyCancellable>()
        var sut: SearchEngineAutocompleter!
        let beamHelper = BeamTestsHelper()
        let searchEngine = GoogleSearch()

        beforeEach {
            sut = SearchEngineAutocompleter(searchEngine: searchEngine)
        }

        describe(".complete(query)") {
            it("updates results") {
                beamHelper.beginNetworkRecording()

                waitUntil(timeout: .seconds(10)) { done in
                    sut.complete(query: "Beam")
                        .sink { results in
                            expect(results.count).to(equal(10))
                            done()
                        }.store(in: &scope)
                }

                beamHelper.endNetworkRecording()
            }

            it("called twice updates results only once") {
                waitUntil(timeout: .seconds(10)) { done in
                    sut.complete(query: "red")
                        .sink { results in
                            fail("1st search should have been cancelled")
                        }.store(in: &scope)

                    beamHelper.beginNetworkRecording()
                    // 2nd call cancel previous query immediately
                    sut.complete(query: "green")
                        .sink { results in
                            expect(results.count).to(equal(10))
                            done()
                        }.store(in: &scope)
                    beamHelper.endNetworkRecording()
                }
            }
        }
    }
}
