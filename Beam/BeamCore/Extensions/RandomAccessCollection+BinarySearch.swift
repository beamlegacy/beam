//
//  RandomAccessCollection+BinarySearch.swift
//  Beam
//
//  Created by Sebastien Metrot on 12/04/2021.
//

import Foundation

public extension RandomAccessCollection {
    /// Finds such index N that predicate is true for all elements up to
    /// but not including the index N, and is false for all elements
    /// starting with index N.
    /// Behavior is undefined if there is no such N.
    func binarySearch(predicate: (Element) -> Bool) -> Index? {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
            if predicate(self[mid]) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }

        if low == startIndex {
            return low
        }

        return low < endIndex && predicate(self[index(before: low)]) ? low : nil
    }

    func binaryContains(_ element: Element) -> Bool where Element: Comparable {
        guard !isEmpty else { return false }
        guard let index = binarySearch(predicate: { elem -> Bool in
            element > elem
        }) else { return false }
        return self[index] == element
    }
}
