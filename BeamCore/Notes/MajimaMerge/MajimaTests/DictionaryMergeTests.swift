import Foundation
import XCTest
import Quick
@testable import BeamCore

class DictionaryMergeTests: QuickSpec {
    override func spec() {
        describe("object merge") {
            it("merges from nil key to mine/your") {
                let result = ThreeWayMerge.merge(
                    base: ["id": "3"],
                    mine: ["id": "3", "name": "John", "phone": "123-456-789"],
                    theirs: ["id": "3", "email": "john@example.com", "phone": "123-456-789"])

                assertMerged(result) {
                    XCTAssertEqual($0, ["id": "3", "name": "John", "email": "john@example.com", "phone": "123-456-789"])
                }
            }

            it("merges from some key to mine/your") {
                let result = ThreeWayMerge.merge(
                    base: ["id": "id1", "phone": "123-456-789"],
                    mine: ["id": "id1", "phone": "123-456-789"],
                    theirs: ["id": "id1", "phone": "000-000-000"]
                )

                assertMerged(result) {
                    XCTAssertEqual($0, ["id": "id1", "phone": "000-000-000"])
                }
            }

            it("merges from some key to nil") {
                let result = ThreeWayMerge.merge(
                    base: ["id": "3", "phone": "123-456-789"],
                    mine: ["id": "3", "email": "test@example.com", "phone": "123-456-789"],
                    theirs: ["id": "3"]
                )

                assertMerged(result) {
                    XCTAssertEqual($0, ["id": "3", "email": "test@example.com"])
                }
            }

            it("finds conflicts") {
                let result = ThreeWayMerge.merge(
                    base: ["id": 3],
                    mine: ["id": 4],
                    theirs: ["id": 5]
                )

                assertConflicted(result)
            }
        }
    }
}
