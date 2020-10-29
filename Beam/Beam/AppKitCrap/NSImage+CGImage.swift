//
//  NSImage+CGImage.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/10/2020.
//

import Foundation
import AppKit

extension NSImage {
    var cgImage: CGImage {
        let imageData = self.tiffRepresentation!
        let source = CGImageSourceCreateWithData(imageData as CFData, nil).unsafelyUnwrapped
        let maskRef = CGImageSourceCreateImageAtIndex(source, Int(0), nil)
        return maskRef.unsafelyUnwrapped
    }
}
