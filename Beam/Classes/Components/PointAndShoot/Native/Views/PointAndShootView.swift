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
    @State private var isConfirmation: Bool = false
    @State private var offset: CGFloat = 0
    @State private var allowAnimation: Bool = false

    var point: UnitPoint {
        UnitPoint(
            x: (1 / pns.page.frame.width) * pns.mouseLocation.x,
            y: (1 / pns.page.frame.height) * pns.mouseLocation.y
        )
    }

    private var transitionIn: AnyTransition {
        AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.2))
            .combined(with: AnyTransition.scale(scale: 0.98, anchor: point).animation(.spring(response: 0.4, dampingFraction: 0.75)))
    }

    var transitionOut: AnyTransition {
        AnyTransition.scale(scale: 1.03, anchor: point).animation(Animation.easeInOut(duration: 0.1))
            .combined(with: AnyTransition.scale(scale: 0.7, anchor: point).animation(Animation.easeInOut(duration: 0.25).delay(0.1)))
            .combined(with: AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.3)))
    }

    @ViewBuilder var body: some View {
        // MARK: - Pointing and Shooting rect
        if let activeGroup = pns.activeShootGroup ?? pns.activePointGroup {
            if activeGroup.targets.count == 1,
               let target = activeGroup.targets.first {
                // MARK: - Pointing
                let isPointing = (pns.hasGraceRectAndMouseOverlap(target, activeGroup.href, pns.mouseLocation) && pns.isAltKeyDown && !pns.isLargeTargetArea(target) && !pns.isTypingOnWebView) || pns.activeShootGroup != nil

                let rectangleGroup = isPointing ? activeGroup : pns.convertTargetToCircleShootGroup(target, activeGroup.href)

                if isPointing {
                    PointAndShootRectangleFrame(pns: pns, group: pns.translateAndScaleGroup(rectangleGroup), isRect: isPointing)
                        .id("rectangle shoot frame")
                        .zIndex(19) // for animation to work correctly
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: transitionOut
                        ))
                }
            } else {
                // MARK: - Selecting
                PointAndShootPathFrame(group: pns.translateAndScaleGroup(activeGroup))
                    .id(activeGroup.id)
                    .zIndex(19) // for animation to work correctly
                    .transition(.asymmetric(
                        insertion: transitionIn,
                        removal: transitionOut
                    ))
            }
        }

        // MARK: - CollectedFrames
        if pns.isAltKeyDown && !pns.hasActiveSelection {
            ForEach(pns.collectedGroups, id: \.id) { collectedGroup in
                PointAndShootPathFrame(group: pns.translateAndScaleGroup(collectedGroup), isCollected: true)
                    .id(collectedGroup.id)
            }
        }

        // MARK: - ShootConfirmation
        if let group = pns.shootConfirmationGroup ?? pns.activeShootGroup {
            let size =  pns.shootConfirmationGroup == nil ? CGSize(width: 300, height: 80) : CGSize(width: 300, height: 42)
            PointAndShootCardPickerPositioning(group: pns.translateAndScaleGroup(group), cardPickerSize: size) {
                FormatterViewBackground {
                    PointAndShootCardPicker(completedGroup: pns.shootConfirmationGroup, allowAnimation: $allowAnimation)
                        .onComplete { (noteTitle, note) in
                            if let noteTitle = noteTitle,
                               let shootGroup = pns.activeShootGroup {
                                pns.addShootToNote(noteTitle: noteTitle, withNote: note, group: shootGroup)
                                self.offset = 10
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                    self.offset = 0
                                }
                            } else {
                                pns.dismissShoot()
                            }
                        }
                }
            }
            .animation(allowAnimation ? .spring(response: 0.4, dampingFraction: 0.58) : nil)
            .zIndex(21) // for animation to work correctly
            .transition(.asymmetric(
                insertion: transitionIn,
                removal: transitionOut
            ))
            .pointAndShootOffsetWithAnimation(y: offset, animation: .spring(response: 0.2, dampingFraction: 0.58))
            .id(group.id)
        }
    }
}
