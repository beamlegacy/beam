//
//  BeamHostingView.swift
//  Beam
//
//  Created by Remi Santos on 13/05/2022.
//

import SwiftUI

/// Simple SwiftUI View Wrapper for AppKit Views
class BeamHostingView<Content>: NSHostingView<Content> where Content: View {
    required public init(rootView: Content) {
        super.init(rootView: rootView)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        assert(false)
    }

    public override var allowsVibrancy: Bool { false }
}
