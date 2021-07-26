//
//  Utilities.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 20/07/2021.
//

import Foundation

func logTimeDecay(duration: Float, halfLife: Float) -> Float {
    return -(duration * log(2) / halfLife)
}

func timeDecay(duration: Float, halfLife: Float) -> Float {
    return exp(logTimeDecay(duration: duration, halfLife: halfLife))
}
