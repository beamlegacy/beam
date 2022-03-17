//
//  DistributedRandomGenerator.swift
//  Beam
//
//  Created by Remi Santos on 22/02/2022.
//

import Foundation

/// A random number generator for a given range while avoiding the already used values and trying to distribute the numbers a little more evenly.
///
/// Using values that were already chosen, the generator tries to find a new value that maximizes the minimum distance with any of the previous choices
struct DistributedRandomGenerator<T: Numeric & Comparable> {
    var range: Range<T>
    var taken = [T]()
    let numTentatives: Int = 10
}
//// Implementating only the Double version of it for now.
//// Couldn't really figure out a great way to use some of the range features while keeping the generic usage.
//// Discussion for ref: https://beamappworkspace.slack.com/archives/C021XBPAQG3/p1645527360840369
extension DistributedRandomGenerator where T == Double {
    func generate() -> Double {
        guard taken.count > 0 else {
            let hueToReturn = Double.random(in: range)
            return hueToReturn
        }
        var hue: Double?
        var distance = -0.1
        for _ in 0..<numTentatives {
            let hueTemp = Double.random(in: range)
            let distanceTemp = taken.map { pow($0 - hueTemp, 2.0) }.min()
            if let distanceTemp = distanceTemp,
               distanceTemp > distance {
                distance = distanceTemp
                hue = hueTemp
            }
        }
        let hueToReturn = hue ?? Double.random(in: range)
        return hueToReturn
    }
}
