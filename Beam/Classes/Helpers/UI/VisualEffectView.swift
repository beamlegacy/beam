//
//  VisualEffectView.swift
//  Beam
//
//  Created by Remi Santos on 27/08/2021.
//

import SwiftUI

/// SwiftUI wrapper for a NSVisualEffectView
struct VisualEffectView: View {
    private var material: NSVisualEffectView.Material
    private var blendingMode: NSVisualEffectView.BlendingMode
    private var state: NSVisualEffectView.State
    private let isEmphasized: Bool

    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        emphasized: Bool = false,
        state: NSVisualEffectView.State = .followsWindowActiveState
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = emphasized
        self.state = state
    }

    var body: some View {
        Representable(
            material: material,
            blendingMode: blendingMode,
            state: state,
            isEmphasized: isEmphasized
        ).accessibility(hidden: true)
    }
}

// MARK: - Representable
extension VisualEffectView {
    struct Representable: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode
        var state: NSVisualEffectView.State
        var isEmphasized: Bool

        func makeNSView(context: Context) -> NSVisualEffectView {
            context.coordinator.visualEffectView
        }

        func updateNSView(_ view: NSVisualEffectView, context: Context) {
            context.coordinator.update(material: material)
            context.coordinator.update(blendingMode: blendingMode)
            context.coordinator.update(state: state)
            context.coordinator.update(isEmphasized: isEmphasized)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

    }

    class Coordinator {
        let visualEffectView = NSVisualEffectView()

        init() {
            visualEffectView.blendingMode = .withinWindow
        }

        func update(material: NSVisualEffectView.Material) {
            visualEffectView.material = material
        }

        func update(blendingMode: NSVisualEffectView.BlendingMode) {
            visualEffectView.blendingMode = blendingMode
        }

        func update(state: NSVisualEffectView.State) {
            visualEffectView.state = state
        }

        func update(isEmphasized: Bool) {
            visualEffectView.isEmphasized = isEmphasized
        }
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
