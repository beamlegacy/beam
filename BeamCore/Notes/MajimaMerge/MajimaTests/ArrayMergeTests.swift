import Foundation
import XCTest
import Quick
@testable import BeamCore

class ArrayMergeTests: QuickSpec {
    override func spec() {
        describe("apply") {
            let a = ["a", "b", "c"]

            it("returns input") {
                let b = applyPatch(base: a, patch: [])
                XCTAssertEqual(a, b)
            }

            it("delete element") {
                let b = applyPatch(base: a, patch: [.Deletion(0), .Deletion(2)])
                XCTAssertEqual(b, ["b"])
            }

            it("inserts element") {
                let b = applyPatch(base: a, patch: [.Insertion(0, "x"), .Insertion(3, "d"), .Insertion(3, "e")])
                XCTAssertEqual(b, ["x", "a", "b", "c", "d", "e"])
            }
        }

        describe("merge") {
            it("merges") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c"], mine: ["x", "b", "c"], theirs: ["a", "b", "y"])
                assertMerged(d, expected: ["x", "b", "y"])
            }

            it("merges2") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c"], mine: ["x", "b", "c"], theirs: ["a", "b", "y", "z"])
                assertMerged(d, expected: ["x", "b", "y", "z"])
            }

            it("merges3") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c"], mine: ["x", "b", "y"], theirs: ["a", "b", "y"])
                assertMerged(d, expected: ["x", "b", "y"])
            }

            it("merges4") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c"], mine: ["a", "x", "X", "b", "c"], theirs: ["a", "b", "y", "Y", "c"])
                assertMerged(d, expected: ["a", "x", "X", "b", "y", "Y", "c"])
            }

            it("merges5") {
                let d = ThreeWayMerge.merge(base: ["a", "b"], mine: ["a", "1", "b"], theirs: ["a", "2"])
                assertMerged(d, expected: ["a", "1", "2"])
            }

            it("merges6") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c"], mine: ["a", "b", "x", "c"], theirs: ["a", "b", "y", "c"])
                assertConflicted(d)
            }

            it("merges7") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c", "d"], mine: ["a", "x", "b", "d"], theirs: ["a", "b", "c", "y", "z", "e"])
                assertMerged(d, expected: ["a", "x", "b", "y", "z", "e"])
            }
        }
    }
}
