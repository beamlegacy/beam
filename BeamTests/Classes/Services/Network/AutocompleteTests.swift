import Foundation
import XCTest
import Quick
import Nimble
import Combine

@testable import Beam
class AutocompleteTests: QuickSpec {
    var sut: Completer!

    override func spec() {
        var scope = Set<AnyCancellable>()

        beforeEach {
            self.sut = Completer()
        }
        describe(".complete(query)") {

            it("updates results") {
                waitUntil(timeout: .seconds(10)) { done in
                    self.sut.$results
                        .dropFirst(1)
                        .sink { results in
                            expect(results).to(haveCount(10))
                            done()
                        }.store(in: &scope)
                    self.sut.complete(query: "Beam")
                }
            }

            it("has an empty first call") {
                waitUntil(timeout: .seconds(10)) { done in
                    self.sut.$results
                        .sink { results in
                            expect(results).to(haveCount(0))
                            done()
                        }.store(in: &scope)
                }
            }

            it("called twice updates results only once") {
                waitUntil(timeout: .seconds(10)) { done in
                    self.sut.$results
                        .dropFirst(1)
                        .sink { results in
                            expect(results).to(haveCount(10))
                            done()
                        }.store(in: &scope)
                    self.sut.complete(query: "Beam")
                    // 2nd call cancel previous query immediatly
                    self.sut.complete(query: "Beam app")
                }
            }
        }
    }
}
