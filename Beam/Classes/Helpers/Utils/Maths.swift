//
//  Maths.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//

import Foundation

public extension Comparable {

    func clamp(_ minValue: Self, _ maxValue: Self) -> Self {
        return min(max(self, minValue), maxValue)
    }

    func clampInLoop(_ minValue: Self, _ maxValue: Self) -> Self {
        if self < minValue {
            return maxValue
        } else if self > maxValue {
            return minValue
        }
        return self
    }
}
