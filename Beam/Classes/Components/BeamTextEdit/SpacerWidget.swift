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

   init(parent: Widget, spacerType: SpacerType) {
        self.spacerType = spacerType
        super.init(parent: parent)
    }

    override func updateRendering() -> CGFloat {
        switch spacerType {
        case .top:
            return editor.journalMode ? 44 : 77
        case .middle:
            return (root?.linksSection?.open ?? true) ? 40 : 6
        case .bottom:
            return 30
        }
    }

    override var mainLayerName: String {
        "Spacer \(spacerType)"
    }
}
