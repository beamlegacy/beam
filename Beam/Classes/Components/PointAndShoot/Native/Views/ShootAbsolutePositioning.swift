import Foundation
import SwiftUI

struct ShootAbsolutePositioning<Content: View>: View {
    @ObservedObject var pns: PointAndShoot
    @ObservedObject var webPositions: WebPositions
    var group: PointAndShoot.ShootGroup
    var contentSize: CGSize
    var content: () -> Content
    let padding: CGFloat = 5

    var body: some View {
        // To reduce overlap with the content we use the last target
        if let target = group.targets.last {
            let target = pns.translateAndScaleTarget(target, group.href)
            GeometryReader { geo in
                let halfWidth = contentSize.width / 2
                let halfHeight = contentSize.height / 2
                let geoX = (target.mouseLocation.x + halfWidth).clamp(target.rect.minX, (geo.size.width - contentSize.width))
                let geoY = (target.mouseLocation.y + halfHeight).clamp(target.rect.minY, geo.size.height - contentSize.height)
                let x = geoX.clamp(target.rect.minX, target.rect.maxX)
                let y = geoY.clamp(target.rect.minY, target.rect.maxY)
                content()
                    .position(x: x, y: y)
            }
        }
    }
}
