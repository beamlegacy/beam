import Foundation
import XCTest
import Quick
import Nimble
import Combine

@testable import Beam
class AutocompleteTests: QuickSpec {
    override func spec() {
        var scope = Set<AnyCancellable>()
        var sut: Autocompleter!
        let beamHelper = BeamTestsHelper()

        beforeEach {
            sut = Autocompleter()
        }

        describe(".complete(query)") {
            it("updates results") {
                beamHelper.beginNetworkRecording()

                waitUntil(timeout: .seconds(10)) { done in
                    sut.$results
                        .dropFirst(1)
                        .sink { results in
                            expect(results.count).to(equal(10))
                            done()
                        }.store(in: &scope)
                    sut.complete(query: "Beam")
                }

                beamHelper.endNetworkRecording()
            }

            it("has an empty first call") {
                beamHelper.beginNetworkRecording()

                waitUntil(timeout: .seconds(10)) { done in
                    sut.$results
                        .sink { results in
                            expect(results.count).to(equal(0))
                            done()
                        }.store(in: &scope)
                }

                beamHelper.endNetworkRecording()
            }

            it("called twice updates results only once") {
                waitUntil(timeout: .seconds(10)) { done in
                    sut.$results
                        .dropFirst(1)
                        .sink { results in
                            expect(results.count).to(equal(10))
                            done()
                        }.store(in: &scope)

                    sut.complete(query: "Hello")
                    beamHelper.beginNetworkRecording()
                    // 2nd call cancel previous query immediatly
                    sut.complete(query: "Hello world")
                    beamHelper.endNetworkRecording()
                }
            }
        }
    }
}
