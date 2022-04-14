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

    /// Event type indicates that the event is most likely coming from a direct user interaction (mouse click, gesture, etc.)
    var isUserInteractionEvent: Bool {
        let isSystemEvents = [.appKitDefined, .flagsChanged, .periodic, .pressure, .systemDefined, .mouseMoved].contains(self.type)
        return !isSystemEvents
    }

}
