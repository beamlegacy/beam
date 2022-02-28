import Foundation
import XCTest
@testable import BeamCore

func assertMerged<T: Equatable>(_ result: MergeResult<T>, expected: T, file: StaticString = #file, line: UInt = #line) {
    switch result {
    case .Conflicted:
        XCTAssertFalse(true, "\(result)", file: file, line: line)
    case .Merged(let obj):
        XCTAssertEqual(obj, expected, file: file, line: line)
    }
}

func assertMerged<T: Equatable>(_ result: MergeResult<[T]>, expected: [T], file: StaticString = #file, line: UInt = #line) {
    switch result {
    case .Conflicted:
        XCTAssertFalse(true, "\(result)", file: file, line: line)
    case .Merged(let obj):
        XCTAssertEqual(obj, expected, file: file, line: line)
    }
}

func assertConflicted<T>(_ result: MergeResult<T>, file: StaticString = #file, line: UInt = #line) {
    switch result {
    case .Conflicted:
        XCTAssert(true, file: file, line: line)
    case .Merged(let obj):
        XCTAssert(false, "\(obj)", file: file, line: line)
    }
}

func applyPatch<T: Equatable>(base: [T], patch: [ArrayDiff<T>]) -> [T] {
    var array = base

    for diff in patch.reversed() {
        array = ThreeWayMerge.apply(base: array, diff: diff)
    }

    return array
}

func assertMerged<T>(_ result: MergeResult<T>, file: StaticString = #file, line: UInt = #line, test: @escaping (T) -> Void) {
    switch result {
    case .Merged(let x):
        test(x)
    case .Conflicted:
        XCTAssert(false, "Unexpected .Conflicted", file: file, line: line)
    }
}
