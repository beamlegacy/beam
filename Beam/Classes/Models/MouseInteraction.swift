//
//  MouseInteraction.swift
//  Beam
//
//  Created by Remi Santos on 15/03/2021.
//

import Foundation

public enum MouseInteractionType {
    case hovered
    case clicked
    case unknown
}

// Mouse Interaction within text range
public struct MouseInteraction {
    let type: MouseInteractionType
    let range: NSRange
}

// Generic Mouse Info for an event
struct MouseInfo {
    var position: NSPoint
    var event: NSEvent
    var globalPosition: NSPoint
    var rightMouse: Bool = false

    init(_ node: Widget, _ position: NSPoint, _ event: NSEvent) {
        self.position = NSPoint(x: position.x - node.offsetInDocument.x, y: position.y - node.offsetInDocument.y)
        self.globalPosition = position
        self.event = event
        self.rightMouse = event.isRightClick
    }

    init(_ node: Widget, _ layer: Layer, _ info: MouseInfo) {
        self.globalPosition = info.globalPosition
        self.event = info.event
        self.rightMouse = info.rightMouse
        self.position = Self.convert(globalPosition: info.globalPosition, node, layer)
    }

    static func convert(globalPosition: NSPoint, _ node: Widget, _ layer: Layer) -> NSPoint {
        guard let editor = node.editor else { return .zero }
        let globalBounds = layer.layer.convert(layer.layer.bounds, to: editor.layer)
        return CGPoint(x: globalPosition.x - globalBounds.minX, y: globalPosition.y - globalBounds.minY)
    }
}
