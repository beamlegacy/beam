import Foundation
import SwiftUI

struct ShootFrameSelectionView: View {
    @ObservedObject var pns: PointAndShoot
    @ObservedObject var webPositions: WebPositions
    var group: PointAndShoot.ShootGroup
    @State private var isHovering = false
    @State var showLabel = false

    var body: some View {
        let newGroup = translate(group)
        let rect = newGroup.groupRect
        let groupPath = newGroup.groupPath
        let text = (isHovering || showLabel) ? newGroup.noteInfo.title : ""
        return Group {
            if let firstUI = newGroup.targets.first {
                let bgColor = BeamColor.PointShoot.shootBackground.swiftUI
                let animated = firstUI.animated
                let color = BeamColor.PointShoot.shootOutline.swiftUI

                ZStack(alignment: .center) {
                    Path(groupPath)
                        .fill(bgColor)
                        .accessibility(identifier: "ShootFrameSelection")

                    ZStack {
                        Rectangle().fill(Color.clear) // needed  to enable hover
                        Text(text)
                            .foregroundColor(color)
                            .accessibility(identifier: "ShootFrameSelectionLabel")
                    }
                    .onHover { isHovering = $0 }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
                }
                .allowsHitTesting(false)
                .animation(animated ? Animation.easeOut : nil)
            }
        }
    }

    func translate(_ group: PointAndShoot.ShootGroup) -> PointAndShoot.ShootGroup {
        var newGroup = group
        let href = group.href
        for target in newGroup.targets {
            let newTarget = pns.translateAndScaleTarget(target, href)
            newGroup.updateTarget(newTarget)
        }

        return newGroup
    }
}
