//
//  ClosedRange+Beam.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation

extension ClosedRange {
    func clamp(_ value : Bound) -> Bound {
        return self.lowerBound > value ? self.lowerBound
            : self.upperBound < value ? self.upperBound
            : value
    }
}
