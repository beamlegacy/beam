import Foundation
import SwiftUI

struct PointAndShootRectangleFrame: View {
    var pns: PointAndShoot
    var group: PointAndShoot.ShootGroup
    var isRect: Bool = true

    private let padding: CGFloat = 4
    @State private var scale: CGFloat = 1
    @State private var lastId: String = ""

    var body: some View {
        if let target = group.targets.first {
            let background = pns.activeShootGroup == nil ? BeamColor.PointShoot.pointBackground.swiftUI : BeamColor.PointShoot.shootBackground.swiftUI
            let rect = target.rect.insetBy(dx: -padding, dy: -padding)
            let x: CGFloat = (rect.minX + rect.width / 2)
            let y: CGFloat = (rect.minY + rect.height / 2)

            let shouldAnimate = pns.activeShootGroup == nil && self.scale == 1  && self.lastId != pns.activeShootGroup?.id

            RoundedRectangle(cornerRadius: isRect ? padding : 20, style: .continuous)
                .fill(background)
                .animation(.easeInOut(duration: 0.2), value: background)
                .scaleEffect(scale)
                .animation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.2), value: scale)
                .frame(width: rect.width, height: rect.height)
                .position(x: x, y: y)
                .animation(shouldAnimate ? .spring(response: 0.2, dampingFraction: 0.88, blendDuration: 0.4) : nil, value: rect)
                .onReceive(pns.$activeShootGroup, perform: { shootGroup in
                    // if nil set to true
                    // only update value when it should change
                    if let group = shootGroup, self.scale == 1, self.lastId != group.id {
                        self.lastId = group.id
                        self.scale = 0.95
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                            self.scale = 1
                        }
                    }
                })
                .pointAndShootFrameOffset(pns, target: target)
                .allowsHitTesting(false)
                .accessibility(identifier: "PointFrame")
        }
    }
}
