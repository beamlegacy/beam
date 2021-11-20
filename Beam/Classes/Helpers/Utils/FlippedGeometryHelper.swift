//
//  FlippedGeometryHelper.swift
//  Beam
//
//  Created by Remi Santos on 18/11/2021.
//

import SwiftUI

extension GeometryProxy {

    /// Previous to macOS Monterey, when asking a frame in global to GeometryProxy with `.frame(in: .global)`
    /// it would return a frame in AppKit defaut coordinate space, with `y` starting at the bottom left
    /// Since Monterey, they changed it to respect classic SwiftUI coordinate system with `y` starting at the top left
    func safeTopLeftGlobalFrame(in window: NSWindow?) -> CGRect {
        frame(in: .global).swiftUISafeTopLeftGlobalFrame(in: window)
    }
}

extension CGPoint {

    /// Previous to macOS Monterey, positions from SwiftUI's `.global` Coordinate Space had bottom left as origin
    /// This method make sure we have a top left origin position on any OS
    func swiftUISafeTopLeftPoint(in window: NSWindow?) -> CGPoint {
        CGRect(origin: self, size: .zero).swiftUISafeTopLeftGlobalFrame(in: window).origin
    }

    func flippedPointToBottomLeftOrigin(in window: NSWindow) -> CGPoint {
        CGRect(origin: self, size: .zero).flippedRectToBottomLeftOrigin(in: window).origin
    }

    func flippedPointToTopLeftOrigin(in window: NSWindow) -> CGPoint {
        CGRect(origin: self, size: .zero).flippedRectToTopLeftOrigin(in: window).origin
    }
}

extension CGRect {

    /// Previous to macOS Monterey, frames from SwiftUI's `.global` Coordinate Space had bottom left as origin
    /// This method make sure we have a top left origin frame on any OS
    func swiftUISafeTopLeftGlobalFrame(in window: NSWindow?) -> CGRect {
        if #available(macOS 12, *) {
            return self
        } else {
            var globalRect = self
            if let window = window ?? AppDelegate.main.window {
                globalRect = globalRect.flippedRectToTopLeftOrigin(in: window)
            }
            return globalRect
        }
    }

    func flippedRectToBottomLeftOrigin(in window: NSWindow) -> CGRect {
        var flipped = self
        flipped.origin.y = window.frame.height - self.maxY
        return flipped
    }

    func flippedRectToTopLeftOrigin(in window: NSWindow) -> CGRect {
        var flipped = self
        flipped.origin.y = window.frame.height - self.maxY
        return flipped
    }
}
