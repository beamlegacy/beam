//
//  NSImage+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 07/12/2020.
//

import Foundation
import Cocoa

extension NSImage {
    var cgImage: CGImage {
        let imageData = self.tiffRepresentation!
        let source = CGImageSourceCreateWithData(imageData as CFData, nil).unsafelyUnwrapped
        let maskRef = CGImageSourceCreateImageAtIndex(source, Int(0), nil)
        return maskRef.unsafelyUnwrapped
    }

    func fill(color: NSColor) -> NSImage {
        guard
            size != .zero,
            let image = self.copy() as? NSImage else {
            return self
        }

        image.isTemplate = true
        image.lockFocus()

        NSAppearance.withAppAppearance {
            color.set()
            let imageRect = NSRect(origin: NSPoint.zero, size: image.size)
            imageRect.fill(using: .sourceAtop)
        }

        image.unlockFocus()

        return image
    }

    var jpegRepresentation: Data {
        let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let jpegData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:])!
        return jpegData
    }
}
