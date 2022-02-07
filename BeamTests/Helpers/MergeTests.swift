import Foundation
import XCTest

@testable import Beam

class MergeTests: XCTestCase {
    func testBasicMerge() {
        let ancestor = "A\nB\nC\n"
        let input1 = "NewStart\nA\nB\nC\n"
        let input2 = "A\nB\nC\nNewEnd\n"
        let expectedString = "NewStart\nA\nB\nC\nNewEnd\n"
        let result = Merge.threeWayMergeString(ancestor: ancestor, input1: input1, input2: input2)

        XCTAssertEqual(result, expectedString)
    }

    func testComplexeMerge() {
        let ancestor = "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n"
        let oursString = "Zero\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n"
        let theirsString = "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\nTen\n11\n"

        let expectedString = "Zero\n1\n2\n3\n4\n5\n6\n7\n8\n9\nTen\n11\n"

        let result = Merge.threeWayMergeString(ancestor: ancestor, input1: oursString, input2: theirsString)

        XCTAssertEqual(result, expectedString)
    }
}
