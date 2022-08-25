//
//  TabGroupNode.swift
//  Beam
//
//  Created by Remi Santos on 19/08/2022.
//

import Foundation
import BeamCore

/// Tab Group Nodes are invisible to users for now.
public class TabGroupNode: ElementNode {

    override var shouldDisplayBullet: Bool {
        false
    }

    public override var textCount: Int {
        0 // skippable node
    }

    private var visibleSize: CGSize {
        .zero
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat) {
        super.init(parent: parent, element: element, availableWidth: availableWidth)
        selfVisible = false
    }

}
