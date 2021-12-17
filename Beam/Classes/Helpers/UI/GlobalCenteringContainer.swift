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
 * Needed for Omnibox content to be centered relatively to the window, no matter how much buttons there are left and right.
 */
struct GlobalCenteringContainer<Content: View>: View {
    var content: () -> Content

    var enabled: Bool = true
    var containerGeometry: GeometryProxy?

    func globalCenteringOffsetX(containerGeo: GeometryProxy?, contentGeo: GeometryProxy) -> CGFloat {
        guard enabled else { return 0 }
        var containerGlobal: NSRect
        if let containerGeo = containerGeo {
            containerGlobal = containerGeo.frame(in: .global)
        } else {
            // fallback, but prefer using the container geometry.
            containerGlobal = AppDelegate.main.window?.contentView?.bounds ?? .zero
        }
        let contentGlobal = contentGeo.frame(in: .global)

        let rightSpacing = containerGlobal.maxX - contentGlobal.maxX
        let leftSpacing = contentGlobal.minX - containerGlobal.minX
        let offsetX = leftSpacing - rightSpacing + containerGlobal.minX
        return offsetX
    }

    init(enabled: Bool = true, containerGeometry: GeometryProxy?, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.enabled = enabled
        self.containerGeometry = containerGeometry
    }

    var body: some View {
        GeometryReader { geo in
            UnderlyingSpacers(offsetX: globalCenteringOffsetX(containerGeo: containerGeometry, contentGeo: geo), availableWidth: geo.size.width) {
                content()
            }
        }
    }
}

private struct UnderlyingSpacers<Content: View>: View {
    var content: () -> Content
    var offsetX: CGFloat
    var availableWidth: CGFloat

    @State private var contentSize: CGSize?
    private var debug = false // true to see the offset adjustement

    init(offsetX: CGFloat, availableWidth: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.offsetX = offsetX
        self.availableWidth = availableWidth
    }

    private var freeSpace: CGFloat {
        guard let contentSize = contentSize else {
            return availableWidth
        }
        return max(0, availableWidth - contentSize.width)
    }

    private var leftOffset: CGFloat {
        max(0, min(freeSpace + offsetX, -offsetX))
    }

    private var rightOffset: CGFloat {
        max(0, min(freeSpace - offsetX, offsetX))
    }

    private var shouldFixedSize: Bool {
        freeSpace > 0 && offsetX != 0
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(debug ? Color.orange : Color.clear)
                .frame(width: leftOffset)
            Spacer(minLength: 0)
                .frame(height: 1)
                .border(debug ? Color.blue : Color.clear)
            content()
                .fixedSize(horizontal: shouldFixedSize, vertical: false)
                .readSize(onChange: { size in
                    contentSize = size
                })
                .layoutPriority(2)
            Spacer(minLength: 0)
                .frame(height: 1)
                .border(debug ? Color.blue : Color.clear)
            Rectangle()
                .fill(debug ? Color.orange : Color.clear)
                .frame(width: rightOffset)
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
