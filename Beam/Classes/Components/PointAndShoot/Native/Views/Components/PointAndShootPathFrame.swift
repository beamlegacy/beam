//
//  PathFrame.swift
//  Beam
//
//  Created by Stef Kors on 22/07/2021.
//

import SwiftUI

struct PointAndShootPathFrame: View {
    var group: PointAndShoot.ShootGroup
    var isCollected: Bool = false
    var scrollEventCallback: (NSEvent) -> Void
    @State private var isHovering = false

    var body: some View {
        let rect = group.groupRect
        let x = rect.minX + (rect.width / 2)
        let y = rect.minY + (rect.height / 2)
        let fill = !isCollected || isHovering ? BeamColor.PointShoot.shootBackground.swiftUI : BeamColor.PointShoot.reminiscenceBackground.swiftUI
        ZStack(alignment: .center) {
            Path(group.groupPath)
                .fill(fill)
                .accessibility(identifier: "ShootFrameSelection")

            Rectangle().fill(Color.clear) // needed to enable hover
                .onHover { isHovering = $0 }
                .onScroll({ event in
                    scrollEventCallback(event)
                })
                .frame(width: rect.width, height: rect.height)
                .position(x: x, y: y)
        }
    }
}
