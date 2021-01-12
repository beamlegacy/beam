//
//  CATransaction.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 30/12/2020.
//

import Foundation
import Cocoa

extension CATransaction {

    static func disableAnimations(_ completion: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        completion()
        CATransaction.commit()
    }

}
