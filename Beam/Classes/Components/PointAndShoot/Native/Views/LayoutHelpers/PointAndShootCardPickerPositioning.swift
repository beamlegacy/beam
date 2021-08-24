import Foundation
import SwiftUI

struct PointAndShootCardPickerPositioning<Content: View>: View {
    var group: PointAndShoot.ShootGroup
    var cardPickerSize: CGSize
    var content: () -> Content
    let padding: CGFloat = 5

    @State private var scale: Bool = false
    @State private var opacity: Bool = false

    private var opacityTransition: AnyTransition {
        AnyTransition.opacity.animation(.easeInOut(duration: 0.2))
    }

    private var scaleTransition: AnyTransition {
        AnyTransition.scale(scale: 0.98).animation(.spring(response: 0.4, dampingFraction: 0.75))
    }

    var body: some View {
        // The Positioning logic does the following:
        //  - Positions the card picker component at the mouse cursor location
        //  - Keep the card picker component inside the webViewWindow by changing the alignment
        //  - For shoot areas shorter than the card picker height overlap is reduced by
        //    positioning the card picker component outside the shoot area
        //
        // Last target is only used to get the target's mouseLocation.
        if let target = group.targets.last {
            GeometryReader { webViewFrame in

                // Create a Rect for the CardPickerComponent to make it easier to workz with positioning
                let cardPickerRect = NSRect(x: target.mouseLocation.x, y: target.mouseLocation.y, width: cardPickerSize.width, height: cardPickerSize.height)

                // If the rect height is smaller than the cardPicker height, offset Y to the bottom of the rect
                let groupSmallerThanCardPicker: Bool = group.groupRect.height < cardPickerSize.height
                let smallRectOffsetHeight = groupSmallerThanCardPicker ? group.groupRect.maxY - target.mouseLocation.y : 0

                // If the right edge of the card picker is outside the page width. align the card picker to the right edge
                let leftEdgeOutSideOfWebView: Bool = cardPickerRect.maxX > webViewFrame.size.width
                let frameBoundsOffsetWidth = leftEdgeOutSideOfWebView ? cardPickerSize.width : 0

                // If the bottom edge of the card picker is outside the page height. align the card picker to the bottom edge
                // Also take into account when the smallRectOffsetHeight is applied it should be aligned to the top edge instead
                let bottomEdgeOutsideOfWebView: Bool = cardPickerRect.maxY > webViewFrame.size.height
                let frameBoundsOffsetHeight = bottomEdgeOutsideOfWebView ? -(cardPickerSize.height + smallRectOffsetHeight) : smallRectOffsetHeight

                // Shorthand to position from the top left point instead of the center
                let halfWidth = cardPickerSize.width / 2
                let halfHeight = cardPickerSize.height / 2

                // Sum and calculate the X, Y position
                let x = halfWidth - frameBoundsOffsetWidth
                let y = halfHeight + frameBoundsOffsetHeight

            content()
                .frame(width: cardPickerSize.width, height: cardPickerSize.height, alignment: .topLeading)
                .animation(.spring(response: 0.4, dampingFraction: 0.58), value: cardPickerSize)
                .offset(x: x, y: y)
                .zIndex(20)
                .position(x: target.mouseLocation.x, y: target.mouseLocation.y)
                .animation(.easeInOut(duration: 0.3), value: frameBoundsOffsetWidth)
                .animation(.easeInOut(duration: 0.3), value: frameBoundsOffsetHeight)
            }
        }
    }
}
