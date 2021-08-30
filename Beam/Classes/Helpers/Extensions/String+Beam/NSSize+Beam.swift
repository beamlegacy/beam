//
//  NSSize+Beam.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/08/2021.
//

import Foundation

public extension NSSize {
    func rounded() -> NSSize {
        return NSSize(width: width.rounded(.awayFromZero), height: height.rounded(.awayFromZero))
    }
}
