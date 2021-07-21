//
//  CollectedFrames.swift
//  Beam
//
//  Created by Stef Kors on 12/07/2021.
//

import SwiftUI

struct CollectedFrames: View {
    @ObservedObject var pns: PointAndShoot

    var body: some View {
        if pns.isAltKeyDown {
            ForEach(pns.collectedGroups, id: \.id) { group in
                ShootFrameSelectionView(pns: pns, webPositions: pns.webPositions, group: group, showLabel: true)
                    .id(group.id)
            }
        }
    }
}
