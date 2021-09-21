//
//  TimeInterval+Beam.swift
//  Beam
//
//  Created by Stef Kors on 16/09/2021.
//

import Foundation
import BeamCore

extension TimeInterval {
    /**
     Checks if `since` has passed since `self`.

     - Parameter since: The duration of time that needs to have passed for this function to return `true`.
     - Returns: `true` if `since` has passed since now.
     */
    func hasPassed(since: TimeInterval) -> Bool {
        return BeamDate.now.timeIntervalSinceReferenceDate - self > since
    }
}
