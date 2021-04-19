import Foundation
import SwiftUI

struct ShootFrameSelectionView: View {

    var group: ShootGroupUI
    @State private var isHovering = false
    private let padding: CGFloat = 6

    var body: some View {
        let rect = ShootFrameFusionRect().getRect(shootSelections: group.uis)
        // (let's not use "first!" but provide fallback values instead
        let firstUI = group.uis.first!
        let backgroundColor = isHovering ? firstUI.bgColor : Color.clear
        let animated = firstUI.animated
        let color = firstUI.color
        let text = isHovering ? group.noteInfo.title : ""
        return ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: padding, style: .continuous)
                .stroke(color, lineWidth: 2)
                .background(backgroundColor)
                .padding(-padding)
                .onHover { hovering in
                    isHovering = hovering
                }
            Text(text)
                .foregroundColor(Color.white)
        }
        .animation(animated ? Animation.easeOut : nil)
        .offset(x: rect.minX, y: rect.minY)
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.width / 2, y: rect.height / 2)
    }
}
