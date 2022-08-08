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
                assertConflicted(d)
            }

            it("merges6") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c"], mine: ["a", "b", "x", "c"], theirs: ["a", "b", "y", "c"])
                assertConflicted(d)
            }

            it("merges7") {
                let d = ThreeWayMerge.merge(base: ["a", "b", "c", "d"], mine: ["a", "x", "b", "d"], theirs: ["a", "b", "c", "y", "z", "e"])
                assertMerged(d, expected: ["a", "x", "b", "y", "z", "e"])
            }

            it("merges9") {
                let d = ThreeWayMerge.merge(base: ["a"], mine: ["a", "b"], theirs: ["a", "b", "c"])
                assertMerged(d, expected: ["a", "b", "c"])
            }

            it("merge10") {
                let d = ThreeWayMerge.merge(base: ["dog", "cat"], mine: ["dog", "mouse", "cat"], theirs: ["dog", "moose", "cat"])
                assertConflicted(d)
            }

            it("merge11") {
                let d = ThreeWayMerge.merge(base: ["dog", "cat"], mine: ["dog", "mouse", "cat"], theirs: ["dog", "mouse", "moose", "cat"])
                assertMerged(d, expected: ["dog", "mouse", "moose", "cat"])
            }

            it("merge12") {
                let d = ThreeWayMerge.merge(base: ["bonjour"], mine: ["bonjour", "le"], theirs: ["bonjour", "le", "monde"])
                assertMerged(d, expected: ["bonjour", "le", "monde"])
            }

            it("merges13") {
                let d = ThreeWayMerge.merge(base: ["a"], mine: ["a", "1", "2"], theirs: ["a", "1", "2", "3"])
                assertMerged(d, expected: ["a", "1", "2", "3"])
            }

            it("merges14") {
                let d = ThreeWayMerge.merge(base: ["a"], mine: ["a", "b"], theirs: ["a", "b", "c"])
                assertMerged(d, expected: ["a", "b", "c"])
            }

            it("merges15") {
                let d = ThreeWayMerge.merge(base: ["a"], mine: ["a", "b", "c"], theirs: ["a", "b", "c", "d", "e", "f", "g"])
                assertMerged(d, expected: ["a", "b", "c", "d", "e", "f", "g"])
            }

            it("merges16") {
                let d = ThreeWayMerge.merge(base: ["a"], mine: ["a", "b", "c"], theirs: ["a", "b", "c"])
                assertMerged(d, expected: ["a", "b", "c"])
            }

            it("merges17") {
                let d = ThreeWayMerge.merge(base: ["a"], mine: ["a", "b", "c", "d", "e", "f"], theirs: ["a", "b", "h"])
                assertConflicted(d)
            }

            it("merge18") {
                let d = ThreeWayMerge.merge(base: ["i like swift"], mine: ["i like rust", "i like swift"], theirs: ["i like swift", "i also like git"])
                assertMerged(d, expected: ["i like rust", "i like swift", "i also like git"])
            }
        }
    }
}
