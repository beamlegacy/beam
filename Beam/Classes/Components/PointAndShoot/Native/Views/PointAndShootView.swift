//
//  PointAndShootView.swift
//  Beam
//
//  Created by Stef Kors on 23/07/2021.
//

import SwiftUI

struct PointAndShootView: View {
    static let defaultPickerSize = CGSize(width: 300, height: 42)
    static let smallPickerSize = CGSize(width: 300, height: 42)

    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @ObservedObject var pns: PointAndShoot
    @State private var isConfirmation: Bool = false
    @State private var offset: CGFloat = 0
    @State private var allowAnimation: Bool = false
    @State private var wiggleValue: CGFloat = 0

    private var transitionAnchor: UnitPoint {
        guard let page = pns.page else {
            return UnitPoint(x: pns.mouseLocation.x, y: pns.mouseLocation.y)
        }
        return UnitPoint(
            x: (1 / page.frame.width) * pns.mouseLocation.x,
            y: (1 / page.frame.height) * pns.mouseLocation.y
        )
    }

    private var transitionInOut: AnyTransition {
        let anchor = transitionAnchor
        let transitionIn = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2))
            .combined(with: AnyTransition.scale(scale: 0.98, anchor: anchor).animation(BeamAnimation.easeInOut(duration: 0.2)))
        let transitionOut = AnyTransition.scale(scale: 1.03, anchor: anchor).animation(BeamAnimation.easeInOut(duration: 0.1))
            .combined(with: AnyTransition.scale(scale: 0.7, anchor: anchor).animation(BeamAnimation.easeInOut(duration: 0.25).delay(0.1)))
            .combined(with: AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.3)))
        return AnyTransition.asymmetric(insertion: transitionIn, removal: transitionOut)
    }

    var shouldAnimateRect: Bool {
        pns.activeShootGroup == nil
    }

    let padding: CGFloat = 4

    @State private var scale: CGFloat = 1
    @State private var lastId: String = ""

    func webViewScrollEvent(_ event: NSEvent) {
        if let tab = browserTabsManager.currentTab {
            tab.webView.scrollWheel(with: event)
        }
    }

    @ViewBuilder
    private func renderPointerView(target: PointAndShoot.Target, activeGroup: PointAndShoot.ShootGroup) -> some View {
        /// The JS send it's updates multiple times per milisecond.
        /// To keep the pointing rectangle performant we shouldn't
        /// add or remove the view component, but instead animate
        /// it's properties like opacity.
        let isRect = (!pns.isLargeTargetArea(target) && pns.hasGraceRectAndMouseOverlap(target, activeGroup.href, pns.mouseLocation) && pns.isAltKeyDown && !pns.isTypingOnWebView) || pns.activeShootGroup != nil
        let rectangleGroup = isRect ? activeGroup : pns.convertTargetToCircleShootGroup(target, activeGroup.href)
        if let target = pns.translateAndScaleGroup(rectangleGroup).targets.first {
            let background = pns.activeShootGroup == nil ? BeamColor.PointShoot.pointBackground.swiftUI : BeamColor.PointShoot.shootBackground.swiftUI
            let rect = target.rect.insetBy(dx: -padding, dy: -padding)
            let x: CGFloat = (rect.minX + rect.width / 2)
            let y: CGFloat = (rect.minY + rect.height / 2)
            let opacity: Double = isRect ? 1 : 0

            RoundedRectangle(cornerRadius: isRect ? padding : 20, style: .continuous)
                .fill(background)
                .accessibility(identifier: "PointFrame")
                .animation(.easeInOut(duration: 0.2), value: background)
                .scaleEffect(scale)
                .animation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.2), value: scale)
                .onScroll({ event in
                    webViewScrollEvent(event)
                })
                .frame(width: rect.width, height: rect.height)
                .animation(shouldAnimateRect ? .timingCurve(0.165, 0.84, 0.44, 1, duration: 0.4) : nil, value: rect.width)
                .animation(shouldAnimateRect ? .timingCurve(0.165, 0.84, 0.44, 1, duration: 0.4) : nil, value: rect.height)
                .opacity(opacity)
                .animation(shouldAnimateRect ? .timingCurve(0.165, 0.84, 0.44, 1, duration: 0.2) : nil, value: isRect)
                .position(x: x, y: y)
                .animation(nil)
                .id("rectangle shoot frame")
                .onReceive(pns.$activeShootGroup, perform: { shootGroup in
                    // if nil set to true
                    // only update value when it should change
                    if let group = shootGroup, self.scale == 1, self.lastId != group.id {
                        self.lastId = group.id
                        self.scale = 0.95
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                            self.scale = 1
                        }
                    }
                })
                .pointAndShootFrameOffset(pns, target: target)
                .allowsHitTesting(!pns.isAltKeyDown)
        }
    }

    @ViewBuilder var body: some View {
        // MARK: - Pointing and Shooting rect
        if let activeGroup = pns.activeShootGroup ?? pns.activePointGroup, activeGroup.showRect {
            if activeGroup.targets.count == 1,
               let target = activeGroup.targets.first {
                // MARK: - Pointing
                renderPointerView(target: target, activeGroup: activeGroup)
            } else {
                // MARK: - Selecting
                PointAndShootPathFrame(group: pns.translateAndScaleGroup(activeGroup), scrollEventCallback: webViewScrollEvent)
                    .id(activeGroup.id)
                    .zIndex(19) // for animation to work correctly
                    .transition(transitionInOut)
            }
        }

        // MARK: - CollectedFrames
        if pns.isAltKeyDown && !pns.hasActiveSelection {
            ForEach(pns.collectedGroups, id: \.id) { collectedGroup in
                if !collectedGroup.fullPageCollect {
                    PointAndShootPathFrame(group: pns.translateAndScaleGroup(collectedGroup), isCollected: true, scrollEventCallback: webViewScrollEvent)
                        .id(collectedGroup.id)
                        .allowsHitTesting(!pns.isAltKeyDown)
                }
            }
        }

        // MARK: - ShootConfirmation
        if let group = pns.activeShootGroup ?? pns.shootConfirmationGroup {
            let size =  pns.shootConfirmationGroup == nil ? Self.defaultPickerSize : Self.smallPickerSize
            PointAndShootCardPickerPositioning(group: pns.translateAndScaleGroup(group), cardPickerSize: size) {
                FormatterViewBackgroundV2 {
                    PointAndShootCardPicker(completedGroup: pns.shootConfirmationGroup, allowAnimation: $allowAnimation) { service in
                        guard let group = pns.activeShootGroup, let service = service else { return }
                        pns.shareShootToService(group: group, service: service)
                    } onComplete: { (targetNote, note, completion) in
                        if let targetNote = targetNote,
                           let shootGroup = pns.activeShootGroup {
                            pns.addShootToNote(targetNote: targetNote, withNote: note, group: shootGroup)
                            completion(nil)
                            self.offset = 10
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                self.offset = 0
                            }
                        } else {
                            pns.dismissActiveShootGroup()
                        }
                        if let currentTab = browserTabsManager.currentTab {
                            currentTab.webviewWindow?.makeFirstResponder(currentTab.webView)
                        }
                    }
                }
            }
            .wiggleEffect(animatableValue: wiggleValue)
            .animation(.spring(response: 0.4, dampingFraction: 0.58), value: wiggleValue)
            .animation(allowAnimation ? .spring(response: 0.4, dampingFraction: 0.58) : nil)
            .zIndex(21) // for animation to work correctly
            .transition(transitionInOut)
            .pointAndShootOffsetWithAnimation(y: offset, animation: .spring(response: 0.2, dampingFraction: 0.58))
            .id(group.id)
            .onReceive(pns.$shootConfirmationGroup, perform: { group in
                if group?.confirmation == .failure {
                    self.wiggleValue = 3

                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                        self.wiggleValue = 0
                    }
                }
            })
            .onDisappear {
                // This fixes a crash seemingly caused by SwiftUI animations (commenting the `.transition(transitionInOut)`
                // line in PointAndShootView.swift makes the crash disappear) when showing the point and shoot card picker
                // then going to notes and back to web.
                pns.cancelShoot()
            }
        }
    }
}
