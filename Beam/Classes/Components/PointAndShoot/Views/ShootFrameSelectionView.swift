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
                let backgroundColor = isHovering ? firstUI.bgColor : Color.clear
                let animated = firstUI.animated
                let color = firstUI.color
                ZStack(alignment: .center) {
                    ZStack {
                        let path = Path(groupPath)
                        path
                            .fill(backgroundColor)
                            .overlay(path.stroke(color, lineWidth: 2))
                    }
                    .accessibility(identifier: "ShootFrameSelection")

                    ZStack {
                        Rectangle().fill(Color.clear) // needed  to enable hover
                        Text(text)
                            .foregroundColor(Color.white)
                            .accessibility(identifier: "ShootFrameSelectionLabel")
                    }
                    .onHover { isHovering = $0 }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
                }
                .animation(animated ? Animation.easeOut : nil)
            }
        }
    }
}
