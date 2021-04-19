import Foundation
import SwiftUI

struct PointFrame: View {

    @ObservedObject var pointAndShootUI: PointAndShootUI
    var body: some View {
        if let selectionUI = pointAndShootUI.pointSelection {
            let rect = selectionUI.rect
            let padding: CGFloat = 3
            RoundedRectangle(cornerRadius: padding, style: .continuous)
                    .stroke(selectionUI.color, lineWidth: 2)
                    .animation(selectionUI.animated ? Animation.easeOut : nil)
                    .offset(x: rect.minX, y: rect.minY)
                    .frame(width: rect.width + (padding * 4), height: rect.height + (padding * 4))
                    .position(x: rect.width / 2, y: rect.height / 2)
        }
    }
}
