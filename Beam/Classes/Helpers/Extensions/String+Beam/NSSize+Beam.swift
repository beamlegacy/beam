//
//  NSSize+Beam.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/08/2021.
//

import Foundation

public extension CGSize {
    func rounded(_ rule: FloatingPointRoundingRule = .awayFromZero) -> CGSize {
        return CGSize(width: width.rounded(rule), height: height.rounded(rule))
    }
}
