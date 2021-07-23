import Foundation
import SwiftUI

struct PointAndShootRectangleFrame: View {
    var group: PointAndShoot.ShootGroup
    var isRect: Bool = true
    var opacity: Double = 1
    let customTiming = Animation.timingCurve(0.165, 0.84, 0.44, 1, duration: 0.4)
    let padding: CGFloat = 4

    var body: some View {
        if let target = group.targets.first {
            let rect = target.rect.insetBy(dx: -padding, dy: -padding)
            let cornerRadius = isRect ? padding : 20
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BeamColor.PointShoot.pointBackground.swiftUI)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
                    .opacity(isRect ? 1 : 0)
                    .animation(customTiming)
                    .allowsHitTesting(false)
                    .accessibility(identifier: "PointFrame")
            }
        }
    }
}
