import Foundation
import SwiftUI

struct PointFrame: View {

    @ObservedObject var pointAndShootUI: PointAndShootUI
    var body: some View {
        if let selectionUI = pointAndShootUI.pointSelection {
            let padding: CGFloat = 4
            let rect = selectionUI.rect.insetBy(dx: -padding, dy: -padding)
            RoundedRectangle(cornerRadius: padding, style: .continuous)
                    .stroke(selectionUI.color, lineWidth: 2)
                    .animation(selectionUI.animated ? Animation.easeOut : nil)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
                    .allowsHitTesting(false)
                    .accessibility(identifier: "PointFrame")
        }
    }
}
