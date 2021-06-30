//
//  GlobalCenteringContainer.swift
//  Beam
//
//  Created by Remi Santos on 04/03/2021.
//

import SwiftUI

/**
 * Container that will center its content globally.
 * It will place a rectangle on the left or right so that there is the same amount of space on both side
 * and therefore making the content centered.
 *
 * See Preview for example / play with it.
 * 
 * Needed for OmnibarSearchField to be centered relatively to the window, no matter how much buttons there are left and right.
 */
struct GlobalCenteringContainer<Content: View>: View {
    var content: () -> Content

    var enabled: Bool = true
    var containerGeometry: GeometryProxy?

    func globalCenteringOffsetX(containerGeo: GeometryProxy?, searchStackGeo: GeometryProxy) -> CGFloat {
        guard enabled else { return 0 }
        var containerGlobal: NSRect
        if let containerGeo = containerGeo {
            containerGlobal = containerGeo.frame(in: .global)
        } else {
            // fallback, but prefer using the container geometry.
            containerGlobal = AppDelegate.main.window?.contentView?.bounds ?? .zero
        }
        let stackGlobal = searchStackGeo.frame(in: .global)

        let rightSpacing = containerGlobal.maxX - stackGlobal.maxX
        let leftSpacing = stackGlobal.minX - containerGlobal.minX
        let offsetX = leftSpacing - rightSpacing + containerGlobal.minX
        return offsetX
    }

    init(enabled: Bool, containerGeometry: GeometryProxy?, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.enabled = enabled
        self.containerGeometry = containerGeometry
    }

    var body: some View {
        GeometryReader { geo in
            UnderlyingSpacers(offsetX: globalCenteringOffsetX(containerGeo: containerGeometry, searchStackGeo: geo)) {
                content()
            }
        }
    }
}

private struct UnderlyingSpacers<Content: View>: View {
    var content: () -> Content
    var offsetX: CGFloat

    private var debug = false // true to see the offset adjustement

    init(offsetX: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.offsetX = offsetX
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(debug ? Color.orange : Color.clear)
                .frame(width: max(0, -offsetX))
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            Rectangle()
                .fill(debug ? Color.orange : Color.clear)
                .frame(width: max(0, offsetX))
        }
    }
}

struct GlobalCenteringContainer_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { containerGeometry in
            HStack(spacing: 0) {
                Rectangle().fill(Color.red)
                    .frame(width: 100, height: 20)
                GlobalCenteringContainer(enabled: true, containerGeometry: containerGeometry) {
                    VStack {
                        Text("This is centered")
                        Text("Even with uneven red rectangles")
                    }
                    .border(Color.green)
                }
                Rectangle().fill(Color.red)
                    .frame(width: 50, height: 20)
            }
        }
        .frame(width: 600, height: 50)
    }
}
