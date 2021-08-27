//
//  VisualEffectView.swift
//  Beam
//
//  Created by Remi Santos on 27/08/2021.
//

import SwiftUI

/// SwiftUI wrapper for a NSVisualEffectView
struct VisualEffectView: NSViewRepresentable {
    private let material: NSVisualEffectView.Material
    private let blendingMode: NSVisualEffectView.BlendingMode
    private let isEmphasized: Bool

    init(material: NSVisualEffectView.Material,
         blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
         emphasized: Bool = false) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = emphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = isEmphasized
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

extension View {
    /// Applies a VisualEffectView as background
    func visualEffect(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        emphasized: Bool = false
    ) -> some View {
        background(
            VisualEffectView(
                material: material,
                blendingMode: blendingMode,
                emphasized: emphasized
            )
        )
    }
}
