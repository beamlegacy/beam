import Foundation
import Quick
import XCTest
@testable import BeamCore

struct DiffExample<T: Equatable> {
    let original: [T]
    let new: [T]
    let diff: [ArrayDiff<T>]
    let file: StaticString
    let line: UInt
}

func diffExample<T: Equatable>(original: [T], new: [T], diff: [ArrayDiff<T>], file: StaticString = #file, line: UInt = #line) -> DiffExample<T> {
    return DiffExample<T>(original: original, new: new, diff: diff, file: file, line: line)
}

class DiffTest: QuickSpec {
    override func spec() {
        describe("Diff") {
            let examples = [
                diffExample(original: ["1", "2", "3"], new: ["1", "2", "3"], diff: []),
                diffExample(original: ["1", "2", "3"], new: ["1", "2"], diff: [.Deletion(2)]),
                diffExample(original: ["1", "2", "3"], new: ["1", "2", "3", "4"], diff: [.Insertion(3, "4")]),
                diffExample(original: ["1", "2"], new: ["0", "2"], diff: [.Insertion(0, "0"), .Deletion(0)]),
                diffExample(original: ["1", "2", "3"], new: ["2", "1", "3"], diff: [.Insertion(1, "1"), .Deletion(0)]),
                diffExample(original: ["1", "2", "3"], new: ["2", "3", "4", "5"], diff: [.Insertion(3, "5"), .Insertion(2, "4"), .Deletion(0)])
            ]

            it("calculates diff") {
                let diff = Diff()

                examples.forEach { example in
                    let d = diff.diff(original: example.original, new: example.new)
                    XCTAssertEqual(d, example.diff, file: example.file, line: example.line)
                    XCTAssertEqual(example.new, applyPatch(base: example.original, patch: example.diff))
                }
            }
        }

        describe("String diff") {
            it("calculates string diff without crashing on small texts") {
                let diff = Diff()
                let t1 = BeamText("Summiting the World’s Most Dangerous Mountain | Podcast | Overheard at National Geographic").splitForMerge()
                let t2 = BeamText("https://www.youtube.com/watch?v=3fNf4eoj8jc").splitForMerge()
                let result = diff.diff(original: t1, new: t2)
                XCTAssertNotNil(result)
            }
        }
    }
}
