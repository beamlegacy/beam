//
//  BeamWindowInfo.swift
//  Beam
//
//  Created by Stef Kors on 27/01/2022.
//

import Foundation
import SwiftUI

class BeamWindowInfo: ObservableObject {
    @Published var windowIsResizing = false
    var undraggableWindowRects: [CGRect] = []
    @Published var windowIsMain = true
    @Published var windowFrame = CGRect.zero
    weak var window: NSWindow?

    /// If the window is a BeamWindow, this refers to the ContentView, and may be different from the width from the window frame
    var isCompactWidth: Bool {
        let compactWidthThreshold = 830.0
        if let window = window as? BeamWindow {
            return window.estimatedContentViewWidth <= compactWidthThreshold
        } else {
            return windowFrame.width <= compactWidthThreshold
        }
    }
}
