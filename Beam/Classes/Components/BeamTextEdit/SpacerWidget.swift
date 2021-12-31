//
//  SpacerWidget.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 25/01/2021.
//

import Foundation

class SpacerWidget: Widget {
    enum SpacerType: String {
        case beforeLinks
        case beforeReferences
        case bottom
    }

    var spacerType: SpacerType

    init(parent: Widget, spacerType: SpacerType, availableWidth: CGFloat) {
        self.spacerType = spacerType
        super.init(parent: parent, availableWidth: availableWidth)
    }

    override func updateRendering() -> CGFloat {
        let linksVisible = root?.linksSection?.selfVisible ?? true
        let refsVisible = root?.referencesSection?.selfVisible ?? true
        switch spacerType {
        case .beforeLinks:
            return (linksVisible || refsVisible) ? 44 : 0
        case .beforeReferences:
            let space: CGFloat = (root?.linksSection?.open ?? true) ? 40 : 0
            return (linksVisible && refsVisible) ? space : 0
        case .bottom:
            guard !(editor?.journalMode ?? true) else { return 0 }
            return 30
        }
    }

    override var mainLayerName: String {
        "Spacer \(spacerType)"
    }
}
