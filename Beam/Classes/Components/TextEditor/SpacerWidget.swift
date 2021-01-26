//
//  SpacerWidget.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 25/01/2021.
//

import Foundation

class SpacerWidget: Widget {
    enum SpacerType {
        case top
        case middle
        case bottom
    }

    var spacerType: SpacerType

    private (set) var space: CGFloat = 0
    var open = true

    init(editor: BeamTextEdit, spacerType: SpacerType) {
        self.spacerType = spacerType
        super.init(editor: editor)
    }

    override func updateRendering() {
        switch spacerType {
        case .top:
            space = 77
        case .middle:
            space = (root?.linksSection?.open ?? true) ? 42 : 10
        case .bottom:
            space = 30
        }

        computedIdealSize.height = space
    }

}
