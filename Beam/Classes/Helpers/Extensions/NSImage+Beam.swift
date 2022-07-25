//
//  NSImage+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 07/12/2020.
//

import Foundation
import Cocoa

extension NSImage {
    func cgImage(forProposedRect proposedRect: CGRect) -> CGImage? {
        var rect = proposedRect
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
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
        return NSImage(size: targetSize, flipped: false, drawingHandler: { rect -> Bool in
            self.draw(in: rect)
            return true
        })
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

    convenience init?(data: Data, availableWidth: Double, scale: Double) {
        guard let image = CGImage.from(data: data, availableWidth: availableWidth, scale: scale) else {
            return nil
        }

        let imageWidth = Double(image.width) / scale
        let imageHeight = Double(image.height) / scale

        self.init(cgImage: image, size: CGSize(width: imageWidth, height: imageHeight))
    }
}

extension CGImage {
    class func from(data: Data, availableWidth: Double, scale: Double) -> CGImage? {
        let options: [AnyHashable: Any] = [kCGImageSourceShouldCache: false]

        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary?,
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }

        if width.doubleValue <= availableWidth * scale {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        let maxPixelSize: Double

        if width.doubleValue > height.doubleValue {
            maxPixelSize = availableWidth * scale
        } else {
            maxPixelSize = (height.doubleValue * availableWidth * scale / width.doubleValue).rounded()
        }

        let downsampleOptions: [AnyHashable: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                       kCGImageSourceCreateThumbnailWithTransform: true,
                                                              kCGImageSourceThumbnailMaxPixelSize: maxPixelSize]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary)
    }
}
