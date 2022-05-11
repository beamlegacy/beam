//
//  View+Snapshot.swift
//  Beam
//
//  Created by Remi Santos on 29/04/2022.
//

import SwiftUI

extension View {

    /// Creates an image of the View by wrapping it in a hosting view.
    func snapshot() -> NSImage? {
        let view = NSHostingView(rootView: self)
        view.setFrameSize(view.fittingSize)
        return view.snapshotImage()
    }
}

public extension NSView {

    /// Creates a NSImage from the bitmap image representation of the view
    func snapshotImage() -> NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }
        cacheDisplay(in: bounds, to: rep)
        guard let cgImage = rep.cgImage else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: bounds.size)
    }

}
