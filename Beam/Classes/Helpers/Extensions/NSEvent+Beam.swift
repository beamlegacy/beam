//
//  NSEvent+Beam.swift
//  Beam
//
//  Created by Remi Santos on 10/04/2022.
//

import Foundation

extension NSEvent {

    /// Event is any right mouse type or an event with control modifier
    var isRightClick: Bool {
        let rightClick = [.rightMouseDown, .rightMouseUp, .rightMouseDragged].contains(self.type)
        let controlClick = self.modifierFlags.contains(.control)
        return rightClick || controlClick
    }

    /// Event is any left mouse type
    var isLeftClick: Bool {
        [.leftMouseDown, .leftMouseUp, .leftMouseDragged].contains(self.type)
    }

}
