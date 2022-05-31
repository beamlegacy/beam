import Foundation
import Quick
@testable import BeamCore

class ScalarMergeTests: QuickSpec {
    override func spec() {
        it("merges if not changed") {
            let result = ThreeWayMerge.merge(base: 1, mine: 1, theirs: 1)
            assertMerged(result, expected: 1)
        }

        it("merges to mine") {
            let result = ThreeWayMerge.merge(base: 1, mine: 2, theirs: 1)
            assertMerged(result, expected: 2)
        }

        it("merges to theirs") {
            let result = ThreeWayMerge.merge(base: "a", mine: "a", theirs: "b")
            assertMerged(result, expected: "b")
        }

        it("conflicts") {
            let result = ThreeWayMerge.merge(base: "X", mine: "Y", theirs: "Z")
            assertConflicted(result)
        }
    }
}
