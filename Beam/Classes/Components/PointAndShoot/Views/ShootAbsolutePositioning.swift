import Foundation
import SwiftUI

struct ShootAbsolutePositioning<Content: View>: View {

    var location: CGPoint
    var contentSize: CGSize
    var content: () -> Content
    let padding: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let halfWidth = contentSize.width / 2
            let maxX = geo.size.width - halfWidth - padding
            let x = (location.x + halfWidth).clamp(halfWidth, maxX)
            content()
                    .position(x: x, y: location.y + contentSize.height / 2 + padding)
        }
    }
}
