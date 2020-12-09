//
//  NSImage+BM.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 07/12/2020.
//

import Foundation
import Cocoa

extension NSImage {
    func fill(color: NSColor) -> NSImage {
        guard let image = self.copy() as? NSImage else { return self }

        image.isTemplate = true
        image.lockFocus()

        color.set()

        let imageRect = NSRect(origin: NSPoint.zero, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.unlockFocus()

        return image
    }

}
