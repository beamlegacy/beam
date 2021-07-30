//
//  PathFrame.swift
//  Beam
//
//  Created by Stef Kors on 22/07/2021.
//

import SwiftUI

struct PointAndShootPathFrame: View {
    var group: PointAndShoot.ShootGroup
    var showLabel: Bool = false
    @State private var isHovering = false

    var body: some View {
        let rect = group.groupRect
        let text = (isHovering || showLabel) ? group.noteInfo.title : ""

        ZStack(alignment: .center) {
            Path(group.groupPath)
                .fill(BeamColor.PointShoot.shootBackground.swiftUI)
                .accessibility(identifier: "ShootFrameSelection")

            ZStack {
                Rectangle().fill(Color.clear) // needed  to enable hover
                Text(text)
                    .foregroundColor(BeamColor.PointShoot.shootOutline.swiftUI)
                    .accessibility(identifier: "ShootFrameSelectionLabel")
            }
            .onHover { isHovering = $0 }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.minX + rect.width / 2, y: rect.minY + rect.height / 2)
        }
        .allowsHitTesting(false)
    }
}
