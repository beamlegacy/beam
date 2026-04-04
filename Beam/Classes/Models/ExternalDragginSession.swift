//
//  ExternalDragginSession.swift
//  Beam
//
//  Created by Remi Santos on 30/04/2022.
//

import Foundation
import AppKit

struct ExternalDraggingSession {
    var draggedObject: Any?
    var draggingSource: ExternalDraggingSource
    var draggingItem: NSDraggingItem?
    var draggingSession: NSDraggingSession?
    var dropHandledByBeamUI: Bool = false {
        didSet {
            guard dropHandledByBeamUI != oldValue, let draggingSession else { return }
            draggingSource.updateDropHandledByBeamUI(dropHandledByBeamUI, session: draggingSession)
        }
    }
}

protocol ExternalDraggingSource: NSDraggingSource {
    func endDraggingItem()
    func updateDropHandledByBeamUI(_ handled: Bool, session: NSDraggingSession)
}
