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

    var pngRepresentation: Data {
        let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
        return pngData
    }

    // MARK: - Resizing
    /// Resize the image to the given size.
    ///
    /// - Parameter size: The size to resize the image to.
    /// - Returns: The resized image.
    func resize(withSize targetSize: NSSize) -> NSImage? {
        let frame = NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        guard let representation = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        let image = NSImage(size: targetSize, flipped: false, drawingHandler: { (_) -> Bool in
            return representation.draw(in: frame)
        })

        return image
    }

    /// Copy the image and resize it to the supplied size, while maintaining it's
    /// original aspect ratio.
    ///
    /// - Parameter size: The target size of the image.
    /// - Returns: The resized image.
    func resizeMaintainingAspectRatio(withSize targetSize: NSSize) -> NSImage? {
        let newSize: NSSize
        let widthRatio  = targetSize.width / self.size.width
        let heightRatio = targetSize.height / self.size.height

        if widthRatio > heightRatio {
            newSize = NSSize(width: floor(self.size.width * widthRatio),
                             height: floor(self.size.height * widthRatio))
        } else {
            newSize = NSSize(width: floor(self.size.width * heightRatio),
                             height: floor(self.size.height * heightRatio))
        }
        return self.resize(withSize: newSize)
    }
}
