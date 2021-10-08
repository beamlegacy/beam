//
//  BeamPropertyWrappers.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 07/10/2021.
//

import Foundation

@propertyWrapper
struct OptionalClamped<Value: Comparable> {
    var value: Value?
    let range: ClosedRange<Value>

    init(wrappedValue value: Value?, _ range: ClosedRange<Value>) {
        if let value = value {
            precondition(range.contains(value))
        }
        self.value = value
        self.range = range
    }

    var wrappedValue: Value? {
        get { value }
        set {
            if let newValue = newValue {
                value = min(max(range.lowerBound, newValue), range.upperBound)
            } else {
                value = nil
            }
        }
    }
}
