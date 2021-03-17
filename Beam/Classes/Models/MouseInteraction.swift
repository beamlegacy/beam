//
//  MouseInteraction.swift
//  Beam
//
//  Created by Remi Santos on 15/03/2021.
//

import Foundation

enum MouseInteractionType {
    case hovered
    case clicked
    case unknown
}

struct MouseInteraction {
    let type: MouseInteractionType
    let range: NSRange
}
