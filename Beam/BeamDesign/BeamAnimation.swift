//
//  BeamAnimation.swift
//  Beam
//
//  Created by Remi Santos on 21/09/2021.
//

import SwiftUI

enum BeamAnimation {

    static func defaultiOSEasing(duration: Double) -> Animation {
        Animation.timingCurve(0.25, 0.1, 0.25, 0.1, duration: duration)
    }

    static func easeInOut(duration: Double) -> Animation {
        Animation.easeInOut(duration: duration)
    }

    static func spring(stiffness: Double, damping: Double) -> Animation {
        .interpolatingSpring(stiffness: stiffness, damping: damping)
    }
}
