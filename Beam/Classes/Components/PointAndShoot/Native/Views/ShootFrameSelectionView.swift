import Foundation
import SwiftUI

struct ShootFrameSelectionView: View {

    var group: ShootGroupUI
    @State private var isHovering = false

    var body: some View {
        let rect = group.groupRect
        let groupPath = group.groupPath
        let text = isHovering ? group.noteInfo.title : ""
        return Group {
            if let firstUI = group.uis.first {
                let bgColor = firstUI.bgColor
                let animated = firstUI.animated
                let color = firstUI.color

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
}
