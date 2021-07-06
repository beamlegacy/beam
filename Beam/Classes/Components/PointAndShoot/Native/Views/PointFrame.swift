import Foundation
import SwiftUI

struct PointFrame: View {

    @ObservedObject var pointAndShootUI: PointAndShootUI
    let customTiming = Animation.timingCurve(0.165, 0.84, 0.44, 1, duration: 0.5)
    let padding: CGFloat = 4

    var body: some View {
        if let selectionUI = pointAndShootUI.pointSelection {
            let offset = selectionUI.target.offset
            let offsetX = offset?.x ?? 1
            let offsetY = offset?.y ?? 1
            let animated = selectionUI.animated
            let round = selectionUI.round
            let bgColor = selectionUI.bgColor

            let rect = selectionUI.rect.insetBy(dx: -padding, dy: -padding)

            let cornerRadius: CGFloat = round ? selectionUI.rect.width : 4
            let shouldAnimateOpacity = animated && round
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(bgColor)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: offsetX, y: offsetY)
                    .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
                    .animation(animated ? customTiming : nil)
                    .opacity(round ? 0 : 1)
                    .animation(shouldAnimateOpacity ? customTiming : nil)
                    .allowsHitTesting(false)
                    .accessibility(identifier: "PointFrame")
            }
        }
    }
}
