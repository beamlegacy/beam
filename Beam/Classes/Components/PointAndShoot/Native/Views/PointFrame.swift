import Foundation
import SwiftUI

struct PointFrame: View {
    @ObservedObject var pns: PointAndShoot
    @ObservedObject var webPositions: WebPositions
    let customTiming = Animation.timingCurve(0.165, 0.84, 0.44, 1, duration: 0.4)
    let padding: CGFloat = 4

    var body: some View {
        if let group = pns.activePointGroup,
           let target = group.targets.first {
            let pointTarget = pns.translateAndScaleTarget(target, group.href)
            let showPoint = pns.hasGraceRectAndMouseOverlap(target, group.href, pns.mouseLocation) && pns.isAltKeyDown && !pns.isLargeTargetArea(pointTarget)
            let size: CGFloat = 20
            let circleRect = NSRect(x: pns.mouseLocation.x - (size / 2), y: pns.mouseLocation.y - (size / 2), width: size, height: size)
            let rect = showPoint ? pointTarget.rect.insetBy(dx: -padding, dy: -padding) : circleRect
            let cornerRadius: CGFloat = showPoint ? 4 : size / 2
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BeamColor.PointShoot.pointBackground.swiftUI)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
                    .opacity(showPoint ? 1 : 0)
                    .animation(customTiming)
                    .allowsHitTesting(false)
                    .accessibility(identifier: "PointFrame")
            }
        }
    }
}
