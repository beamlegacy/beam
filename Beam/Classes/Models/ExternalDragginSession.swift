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
    var dropHandledByBeamUI = false
}

protocol ExternalDraggingSource: NSDraggingSource {
    func endDraggingItem()
}
