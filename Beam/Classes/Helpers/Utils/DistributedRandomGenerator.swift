//
//  DistributedRandomGenerator.swift
//  Beam
//
//  Created by Remi Santos on 22/02/2022.
//

import Foundation

/// A random number generator for a given range while avoiding the already used values and trying to distribute the numbers a little more evenly.
///
/// It will use the largest available space in the range to generate a random
/// Exemple:
/// in range `0..<10`, if `3` is taken, it will generate a random between `4..<10`
struct DistributedRandomGenerator<T: Numeric & Comparable> {
    var range: Range<T>
    var taken: [T]
}

// Implementating only the Double version of it for now.
// Couldn't really figure out a great way to use some of the range features while keeping the generic usage.
// Discussion for ref: https://beamappworkspace.slack.com/archives/C021XBPAQG3/p1645527360840369
extension DistributedRandomGenerator where T == Double {
    func randomElement() -> T? {
        guard !taken.isEmpty else {
            return T.random(in: range)
        }
        var largestRange: Range<T> = range.lowerBound..<range.lowerBound
        var all = taken
        all.append(contentsOf: [range.lowerBound, range.upperBound])
        let sorted = all.sorted()

        var previousElement = sorted.first
        sorted.forEach { e in
            guard let prevEl = previousElement else {
                previousElement = e
                return
            }
            let rangeToPrevious = min(prevEl.nextUp, e)..<e
            if (rangeToPrevious.upperBound - rangeToPrevious.lowerBound) > (largestRange.upperBound - largestRange.lowerBound) {
                largestRange = rangeToPrevious
            }
            previousElement = e
        }
        return T.random(in: largestRange)
    }
}
