import Foundation
import BeamCore

class Merge {
    static private func stringToMergeFileInputPointer(_ string: String, _ filename: String? = nil) -> UnsafeMutablePointer<git_merge_file_input>? {
        let result = UnsafeMutablePointer<git_merge_file_input>.allocate(capacity: 1)
        guard git_merge_file_input_init(result, UInt32(GIT_MERGE_FILE_INPUT_VERSION)) == 0 else {
            return nil
        }
        result.pointee.ptr = UnsafePointer<Int8>((string as NSString).utf8String)
        result.pointee.size = string.utf8CString.count - 1
        if let filename = filename {
            result.pointee.path = UnsafePointer<Int8>((filename as NSString).utf8String)
        }
        return result
    }

    static func threeWayMergeData(ancestor: Data, input1: Data, input2: Data) -> Data? {
        guard let ancestorString = String(data: ancestor, encoding: .utf8),
              let input1String = String(data: input1, encoding: .utf8),
              let input2String = String(data: input2, encoding: .utf8) else {
            return nil
        }
        return threeWayMergeString(ancestor: ancestorString,
                                   input1: input1String,
                                   input2: input2String)?.data(using: .utf8)
    }

    static func threeWayMergeString(ancestor: String, input1: String, input2: String) -> String? {
        git_libgit2_init()

        defer {
            git_libgit2_shutdown()
        }

        guard let ancestorFile = stringToMergeFileInputPointer(ancestor),
              let inputFile1 = stringToMergeFileInputPointer(input1, "input1_local"),
              let inputFile2 = stringToMergeFileInputPointer(input2, "input2_remote")
              else {
            Logger.shared.logDebug("Could not merge", category: .documentMerge)
            return nil
        }

        let options = UnsafeMutablePointer<git_merge_file_options>.allocate(capacity: 1)
        guard git_merge_file_options_init(options, UInt32(GIT_MERGE_OPTIONS_VERSION)) == 0 else {
            Logger.shared.logDebug("Could not merge", category: .documentMerge)
            return nil
        }

        let resultFile = UnsafeMutablePointer<git_merge_file_result>.allocate(capacity: 1)

        git_merge_file(resultFile, ancestorFile, inputFile1, inputFile2, options)

        defer {
            ancestorFile.deallocate()
            inputFile1.deallocate()
            inputFile2.deallocate()
            resultFile.deallocate()
            git_merge_file_result_free(resultFile)
        }

        let fileResult = resultFile.move()
        if fileResult.automergeable != 1 {
            Logger.shared.logDebug("Could not auto merge", category: .documentMerge)

            if let str = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: resultFile.pointee.ptr), length: resultFile.pointee.len, encoding: .utf8, freeWhenDone: false) {
                Logger.shared.logDebug(str, category: .documentMerge)
            }

            return nil
        }

        if let str = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: resultFile.pointee.ptr), length: resultFile.pointee.len, encoding: .utf8, freeWhenDone: false) {
            Logger.shared.logDebug("Could 3 ways merge", category: .documentMerge)
            return String(str)
        }

        Logger.shared.logDebug("Could not merge", category: .documentMerge)

        return nil
    }
}

// https://gist.github.com/kristopherjohnson/543687c763cd6e524c91

/// Find first differing character between two strings
///
/// :param: s1 First String
/// :param: s2 Second String
///
/// :returns: .DifferenceAtIndex(i) or .NoDifference
public func firstDifferenceBetweenStrings(_ s1: NSString, _ s2: NSString) -> FirstDifferenceResult {
    let len1 = s1.length
    let len2 = s2.length

    let lenMin = min(len1, len2)

    for i in 0..<lenMin {
        if s1.character(at: i) != s2.character(at: i) {
            return .DifferenceAtIndex(i)
        }
    }

    if len1 < len2 {
        return .DifferenceAtIndex(len1)
    }

    if len2 < len1 {
        return .DifferenceAtIndex(len2)
    }

    return .NoDifference
}

/// Create a formatted String representation of difference between strings
///
/// :param: s1 First string
/// :param: s2 Second string
///
/// :returns: a string, possibly containing significant whitespace and newlines
public func prettyFirstDifferenceBetweenStrings(_ s1: NSString, _ s2: NSString) -> NSString {
    let firstDifferenceResult = firstDifferenceBetweenStrings(s1, s2)
    return prettyDescriptionOfFirstDifferenceResult(firstDifferenceResult, s1, s2)
}

/// Create a formatted String representation of a FirstDifferenceResult for two strings
///
/// :param: firstDifferenceResult FirstDifferenceResult
/// :param: s1 First string used in generation of firstDifferenceResult
/// :param: s2 Second string used in generation of firstDifferenceResult
///
/// :returns: a printable string, possibly containing significant whitespace and newlines
public func prettyDescriptionOfFirstDifferenceResult(_ firstDifferenceResult: FirstDifferenceResult, _ s1: NSString, _ s2: NSString) -> NSString {

    func diffString(index: Int, s1: NSString, s2: NSString) -> NSString {
        let markerArrow = "\u{2b06}"  // "⬆"
        let ellipsis    = "\u{2026}"  // "…"
        /// Given a string and a range, return a string representing that substring.
        ///
        /// If the range starts at a position other than 0, an ellipsis
        /// will be included at the beginning.
        ///
        /// If the range ends before the actual end of the string,
        /// an ellipsis is added at the end.
        func windowSubstring(_ s: NSString, _ range: NSRange) -> String {
            // swiftlint:disable:next legacy_constructor
            let validRange = NSMakeRange(range.location, min(range.length, s.length - range.location))
            let substring = s.substring(with: validRange)

            let prefix = range.location > 0 ? ellipsis : ""
            let suffix = (s.length - range.location > range.length) ? ellipsis : ""

            return "\(prefix)\(substring)\(suffix)"
        }

        // Show this many characters before and after the first difference
        let windowPrefixLength = 10
        let windowSuffixLength = 10
        let windowLength = windowPrefixLength + 1 + windowSuffixLength

        let windowIndex = max(index - windowPrefixLength, 0)
        // swiftlint:disable:next legacy_constructor
        let windowRange = NSMakeRange(windowIndex, windowLength)

        let sub1 = windowSubstring(s1, windowRange)
        let sub2 = windowSubstring(s2, windowRange)

        let markerPosition = min(windowSuffixLength, index) + (windowIndex > 0 ? 1 : 0)

        let markerPrefix = String(repeating: " ", count: markerPosition)
        let markerLine = "\(markerPrefix)\(markerArrow)"

        return NSString(string: "Difference at index \(index):\n\(sub1)\n\(sub2)\n\(markerLine)")
    }

    switch firstDifferenceResult {
    case .NoDifference:                 return "No difference"
    case .DifferenceAtIndex(let index): return diffString(index: index, s1: s1, s2: s2)
    }
}

/// Result type for firstDifferenceBetweenStrings()
public enum FirstDifferenceResult {
    /// Strings are identical
    case NoDifference

    /// Strings differ at the specified index.
    ///
    /// This could mean that characters at the specified index are different,
    /// or that one string is longer than the other
    case DifferenceAtIndex(Int)
}

extension FirstDifferenceResult {
    /// Textual representation of a FirstDifferenceResult
    public var description: String {
        switch self {
        case .NoDifference:
            return "NoDifference"
        case .DifferenceAtIndex(let index):
            return "DifferenceAtIndex(\(index))"
        }
    }

    /// Textual representation of a FirstDifferenceResult for debugging purposes
    public var debugDescription: String {
        return self.description
    }
}
