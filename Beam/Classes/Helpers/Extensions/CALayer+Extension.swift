//
//  CALayer+Extensions.swift
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

extension CALayer {

    /// Get a`NSImage` representation of the layer.
    ///
    /// - Returns: a `NSImage` of the layer.

    func image() -> NSImage? {
        let width = Int(bounds.width * contentsScale)
        let height = Int(bounds.height * contentsScale)
        guard let imageRepresentation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        imageRepresentation.size = bounds.size

        guard let context = NSGraphicsContext(bitmapImageRep: imageRepresentation) else { return nil }
        render(in: context.cgContext)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(imageRepresentation)
        return image
    }
}
