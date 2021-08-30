//
//  PointAndShootFrameOffset.swift
//  Beam
//
//  Created by Stef Kors on 10/08/2021.
//

import SwiftUI
import Combine

struct PointAndShootFrameOffsetView: ViewModifier {
    @ObservedObject var pns: PointAndShoot
    var target: PointAndShoot.Target
    @State var offset = NSPoint(x: 0, y: 0)
    @State var timer: Timer?
    @State var ignoreOffset: Bool = false
    @State var lastID: String = ""
    @State var space: CGFloat = 1

    func body(content: Content) -> some View {
        let computedOffset = pns.activeShootGroup != nil || ignoreOffset ? NSPoint(x: 0, y: 0) : offset

        return content
            .pointAndShootOffsetWithAnimation(computedOffset, animation: .timingCurve(0.165, 0.84, 0.44, 1, duration: 0.4))
            .onReceive(pns.$mouseLocation, perform: { location in
                let x = calculateDistance(coordinate: location.x, areaCoord: target.rect.minX, areaSize: target.rect.width)
                let y = calculateDistance(coordinate: location.y, areaCoord: target.rect.minY, areaSize: target.rect.height)
                self.offset = NSPoint(x: x, y: y)
            })
    }

    /// Distance from mouselocation to center of rect for one axis
    /// - Parameters:
    ///   - coordinate: coordinate of mouse
    ///   - areaCoord: coordinate of area
    ///   - areaSize: size of area
    /// - Returns: float of distance to center
    func calculateDistance(coordinate: CGFloat, areaCoord: CGFloat, areaSize: CGFloat) -> CGFloat {
        let distance = coordinate - (areaCoord + areaSize / 2)
        let edge: CGFloat = (areaSize / 2) + 40

        let distanceClamp: CGFloat = distance.clamp(-edge, edge)
        let displacement: CGFloat = 10
        let mapped = mapRangeToRange(-edge...edge, -displacement...displacement, to: distanceClamp)
        return mapped
    }

    /// Map number from range of number to range of numbers
    /// - Parameters:
    ///   - range1: from range
    ///   - range2: to range
    ///   - to: the number to map
    /// - Returns: mapped float
    func mapRangeToRange(_ range1: ClosedRange<CGFloat>, _ range2: ClosedRange<CGFloat>, to: CGFloat) -> CGFloat {
        let num = (to - range1.lowerBound) * (range2.upperBound - range2.lowerBound)
        let denom = range1.upperBound - range1.lowerBound

        return range2.lowerBound + num / denom
    }
}

extension View {
    /// Offset element based on mouseLocation and activeShootGroup state. Will animate from offset position back to (x: 0, y: 0) when staying hovered over the same target element
    /// - Parameters:
    ///   - pns: Point and Shoot Object
    ///   - target: Point and Shoot Target to offset
    /// - Returns: offset element
    func pointAndShootFrameOffset(_ pns: PointAndShoot, target: PointAndShoot.Target) -> some View {
        return modifier(PointAndShootFrameOffsetView(pns: pns, target: target))
    }
}
