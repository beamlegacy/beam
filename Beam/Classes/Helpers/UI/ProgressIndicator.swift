//
//  ProgressIndicator.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/02/2021.
//

import SwiftUI

struct ProgressIndicator: NSViewRepresentable {
    typealias NSViewType = NSProgressIndicator

    var isAnimated: Bool
    let controlSize: NSControl.ControlSize

    func makeNSView(context: Context) -> NSProgressIndicator {
        let nsView = NSProgressIndicator()
        nsView.isIndeterminate = true
        nsView.style = .spinning
        nsView.controlSize = controlSize
        return nsView
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {
        nsView.isHidden = !isAnimated
        isAnimated ? nsView.startAnimation(self) : nsView.stopAnimation(self)
    }
}
