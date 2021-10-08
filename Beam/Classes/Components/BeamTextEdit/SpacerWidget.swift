//
//  SpacerWidget.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 25/01/2021.
//

import Foundation

class SpacerWidget: Widget {
    enum SpacerType: String {
        case top
        case middle
        case bottom
    }

    var spacerType: SpacerType

    init(parent: Widget, spacerType: SpacerType, availableWidth: CGFloat?) {
        self.spacerType = spacerType
        super.init(parent: parent, availableWidth: availableWidth)
    }

    override func updateRendering() -> CGFloat {
        switch spacerType {
        case .top:
            return 44
        case .middle:
            return (root?.linksSection?.open ?? true) ? 40 : 10
        case .bottom:
            return 30
        }
    }

    override var mainLayerName: String {
        "Spacer \(spacerType)"
    }
}
