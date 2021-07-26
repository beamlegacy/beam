//
//  PointAndShootView.swift
//  Beam
//
//  Created by Stef Kors on 23/07/2021.
//

import SwiftUI

struct PointAndShootView: View {
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @ObservedObject var pns: PointAndShoot

    var body: some View {
        // MARK: - Pointing and Shooting rect
        if let activeGroup = pns.activeShootGroup ?? pns.activePointGroup {
            if activeGroup.targets.count == 1,
               let target = activeGroup.targets.first {
                let useActiveGroup = pns.hasGraceRectAndMouseOverlap(target, activeGroup.href, pns.mouseLocation) && pns.isAltKeyDown && !pns.isLargeTargetArea(target) && !pns.isTypingOnWebView || pns.activeShootGroup != nil
                let rectangleGroup = useActiveGroup ? activeGroup : pns.convertTargetToCircleShootGroup(target, activeGroup.href)
                PointAndShootRectangleFrame(group: pns.translateAndScaleGroup(rectangleGroup), isRect: useActiveGroup)
            } else {
                PointAndShootPathFrame(group: activeGroup)
                    .id(activeGroup.id)
            }

            // MARK: - ShootConfirmation
            if let shootGroup = pns.activeShootGroup {
                PointAndShootShootAbsolutePositioning(group: pns.translateAndScaleGroup(shootGroup), contentSize: PointAndShootCardPicker.size) {
                    PointAndShootCardPicker()
                        .onComplete { (noteTitle, note) in
                            if let noteTitle = noteTitle {
                                pns.addShootToNote(noteTitle: noteTitle, withNote: note)
                            } else {
                                pns.dismissShoot()
                            }
                        }
                }
            }
        }

        // MARK: - CollectedFrames
        if pns.isAltKeyDown {
            ForEach(pns.collectedGroups, id: \.id) { collectedGroup in
                PointAndShootPathFrame(group: collectedGroup, showLabel: true)
                    .id(collectedGroup.id)
            }
        }

        // MARK: - ShootConfirmation
        if let confirmationGroup = pns.shootConfirmationGroup {
            PointAndShootShootAbsolutePositioning(group: confirmationGroup, contentSize: PointAndShootCardConfirmationBox.size) {
                PointAndShootCardConfirmationBox(group: confirmationGroup)
            }
        }
    }
}
