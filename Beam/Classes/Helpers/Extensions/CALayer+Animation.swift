//
//  CALayer+Animation.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 23/02/2021.
//

import Foundation

extension CALayer {
    var enableAnimations: Bool {
        get { delegate == nil }
        set { delegate = newValue ? nil : CALayerAnimationsDisablingDelegate.shared }
    }
}

private class CALayerAnimationsDisablingDelegate: NSObject, CALayerDelegate {
    static let shared = CALayerAnimationsDisablingDelegate()
    private let null = NSNull()

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        null
    }
}
