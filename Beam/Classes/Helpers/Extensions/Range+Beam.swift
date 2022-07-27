//
//  Range+Beam.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation

extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        return self.lowerBound > value ? self.lowerBound
            : self.upperBound < value ? self.upperBound
            : value
    }

}

// MARK: - Join 
extension ClosedRange where Bound == Int {

    /// Add range before or after if they can form a closed range
    func join(_ range: ClosedRange) -> ClosedRange {

        if self.contains(range.lowerBound - 1) && self.upperBound <= range.upperBound {
            // 10...20 + 15...25
            // 10...20 + 22 ...25
            // append
            return self.lowerBound...range.upperBound
        } else if self.contains(range.upperBound + 1) && self.lowerBound >= range.lowerBound {
            // 10...20 + 5...15
            // 10...20 + 5...8
            // 10...20 + 5...9
            // prepend
            return range.lowerBound...self.upperBound
        } else if range.contains(self.lowerBound) && range.contains(self.upperBound) {
            return range
        }
        return self
    }
}

extension Range where Bound == Int {

    /// Add range before or after if they can form a range
    func join(_ range: Range) -> Range {

        if self.contains(range.lowerBound - 1) && self.upperBound <= range.upperBound {
            // append
            return self.lowerBound..<range.upperBound
        } else if self.contains(range.upperBound + 1) && self.lowerBound >= range.lowerBound {
            // prepend
            return range.lowerBound..<self.upperBound
        } else if range.contains(self.lowerBound) && range.contains(self.upperBound) {
            return range
        }
        return self
    }
}

// MARK: - Convenience

extension Range where Bound: AdditiveArithmetic {
    /// Creates an instance with the given bounds or fails and returns `nil` if bounds are invalid.
    /// - Parameter bounds: A tuple of the lower and upper bounds of the range.
    init?(safeBounds bounds: (lower: Bound, upper: Bound)) {
        guard bounds.lower <= bounds.upper else {
            return nil
        }
        self.init(uncheckedBounds: bounds)
    }
}

extension ClosedRange where Bound: AdditiveArithmetic {
    /// Creates an instance with the given bounds or fails and returns `nil` if bounds are invalid.
    /// - Parameter bounds: A tuple of the lower and upper bounds of the range.
    init?(safeBounds bounds: (lower: Bound, upper: Bound)) {
        guard bounds.lower <= bounds.upper else {
            return nil
        }
        self.init(uncheckedBounds: bounds)
    }
}
