//
//  Tick.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/11/2020.
//

import Foundation
import AppKit

public struct Tick {
    public var now: CFTimeInterval
    public var previous: CFTimeInterval
    public var index: Int
    public var delta = Double(0)
    public var fdelta = Float(0)

    public init() {
        now = CACurrentMediaTime()
        previous = CACurrentMediaTime()
        index = 0
    }
}
