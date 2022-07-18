//
//  EditorTabGroupView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 09/06/2022.
//

import SwiftUI
import BeamCore

struct EditorTabGroupView: View {

    @State var tabGroup: TabGroupBeamObject
    let note: BeamNote

    @Binding var hoveredTab: TabGroupBeamObject.PageInfo?
    @Binding var hoveredGroupFrame: CGPoint?
    @Binding var hoveredGroupColor: Color?

    @State private var isHoverArrow: Bool = false
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    @Environment(\.colorScheme) private var colorScheme

    @State private var nillify: DispatchWorkItem?

    static var height: CGFloat = 34.0

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 1) {
                ZStack {
                    HStack {
                        title
                        Spacer(minLength: 8)
                    }
                    HStack {
                        Spacer()
                        ButtonLabel(icon: "tabs-group_open", customStyle: arrowButtonStyle) {
                            openAllTabs()
                        }
                        .blendModeLightMultiplyDarkScreen()
                        .onHover {
                            isHoverArrow = $0
                        }
                    }
                }
                HStack(spacing: 0) {
                    ForEach(tabGroup.pages) { tab in
                        TabCapsule(color: tabGroup.color?.mainColor?.swiftUI ?? .red)
                            .onTouchDown({ down in
                                if !down {
                                    _ = state.createTab(withURLRequest: URLRequest(url: tab.url))
                                }
                            })
                            .onHover { h in
                                if h {
                                    nillify?.cancel()
                                    nillify = nil

                                    hoveredTab = tab
                                    let frame = proxy.frame(in: .global)
                                    hoveredGroupFrame = CGPoint(x: frame.origin.x + frame.width / 2, y: frame.origin.y + frame.height / 2)
                                    hoveredGroupColor = tabGroup.color?.mainColor?.swiftUI ?? .red
                                } else if hoveredTab == tab {
                                    let nillify = DispatchWorkItem {
                                        hoveredTab = nil
                                        hoveredGroupFrame = nil
                                        hoveredGroupColor = nil
                                    }
                                    self.nillify = nillify
                                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: nillify)
                                }
                            }
                    }
                }.animation(allowAnimation ? .easeIn(duration: 0.1) : nil)
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)
        }
        .background(background)
        .frame(minWidth: 100, maxWidth: 200, idealHeight: Self.height)
    }

    private var allowAnimation: Bool {
        !windowInfo.windowIsResizing
    }

    @ViewBuilder private var title: some View {
        if isHoverArrow {
            Text("Open Tab Group")
                .font(BeamFont.medium(size: 11).swiftUI)
                .transition(titleTransition(reversed: true))
        } else {
            Text(tabGroup.title ?? "Unnamed Tab Group")
                .font(BeamFont.medium(size: 11).swiftUI)
                .lineLimit(1)
                .foregroundColor(BeamColor.Editor.link.swiftUI)
                .transition(titleTransition(reversed: false))
                .allowsHitTesting(false)
        }
    }

    var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(strokeColor, lineWidth: 1)
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        }.overlay(ClickCatchingView(onTap: nil, onRightTap: { event in
            showContextMenu(with: event)
        }, onDoubleTap: nil))
    }

    private let defaultFadeTransition = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
    private let defaultFadeTransitionDelayed = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08).delay(0.03))

    private func titleTransition(reversed: Bool) -> AnyTransition {
        let offsetAnimation = BeamAnimation.spring(stiffness: 380, damping: 20)
        if reversed {
            return .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: 8)).animation(offsetAnimation).combined(with: defaultFadeTransitionDelayed),
                               removal: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(offsetAnimation).combined(with: defaultFadeTransitionDelayed))
        } else {
            return .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(offsetAnimation).combined(with: defaultFadeTransition),
                               removal: .animatableOffset(offset: CGSize(width: 0, height: 8)).animation(offsetAnimation).combined(with: defaultFadeTransition))
        }
    }

    private var strokeColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 1, green: 1, blue: 1).opacity(0.2)
        default:
            return Color(red: 0, green: 0, blue: 0).opacity(0.1)
        }
    }

    private var backgroundColor: Color {
        switch colorScheme {
        case .dark:
            return BeamColor.Mercury.swiftUI
        default:
            return .white
        }
    }

    private let arrowButtonStyle: ButtonLabelStyle = ButtonLabelStyle(iconSize: 10, foregroundColor: BeamColor.AlphaGray.swiftUI, activeForegroundColor: BeamColor.Corduroy.swiftUI, activeBackgroundColor: .clear, trailingPaddingAdjustment: 6)

    private func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()
        weak var state = self.state

        let nameAndColorView = TabClusteringNameColorPickerView(
            groupName: tabGroup.title ?? "",
            selectedColor: tabGroup.color?.designColor ?? .red,
            onChange: { [weak state] newValues in
                if tabGroup.title != newValues.name {
                    tabGroup.title = newValues.name
                    state?.data.tabGroupingDBManager?.save(groups: [tabGroup])
                }
                if tabGroup.color != newValues.color, let newColor = newValues.color {
                    tabGroup.color = newColor
                    state?.data.tabGroupingDBManager?.save(groups: [tabGroup])
                }
            },
            onFinish: { [weak menu] in menu?.cancelTracking() })

        let nameAndColorItemInsets = NSEdgeInsets(top: 4, left: 14, bottom: 8, right: 14)

        let nameAndColorItem = ContentViewMenuItem(
            title: "Name your group item",
            acceptsFirstResponder: !(tabGroup.title?.isEmpty == true),
            contentView: { nameAndColorView },
            insets: nameAndColorItemInsets,
            customization: { hostingView in
                let width = 230 - (nameAndColorItemInsets.left + nameAndColorItemInsets.right)
                hostingView.widthAnchor.constraint(equalToConstant: width).isActive = true
                hostingView.heightAnchor.constraint(equalToConstant: 16).isActive = true
            })

        menu.addItem(nameAndColorItem)
        menu.addItem(.fullWidthSeparator())

        menu.addItem(withTitle: "Open in Background") { _ in
            openAllTabs(options: [.inBackground])
        }
        menu.addItem(withTitle: "Open in New Window") { _ in
            openAllTabs(options: [.newWindow])
        }
        menu.addItem(.separator())

        menu.addItem(withTitle: "Delete Group") { _ in
            let group = TabGroupingStoreManager.convertBeamObjectToGroup(tabGroup)
            TabGroupingManager().ungroup(group)
            if let index = note.tabGroups.firstIndex(of: group.id) {
                note.tabGroups.remove(at: index)
            }
        }

        var location = event.locationInWindow

        // When displayed in the MiniEditorPanel, we need to flip as the contentView is a SwiftUI NSHostingView
        if let window = windowInfo.window, window is MiniEditorPanel {
            location = location.flippedPointToTopLeftOrigin(in: window)
        }

        menu.popUp(positioning: nil, at: location, in: windowInfo.window?.contentView)
    }

    private func openAllTabs(options: Set<BeamState.TabOpeningOption> = []) {
        let group = TabGroupingStoreManager.convertBeamObjectToGroup(tabGroup)
        state.openTabGroup(group, openingOption: options)
    }
}

struct TabGroupInNoteView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
//            EditorTabGroupView(tabGroup: StaticTabGroup.demoGroup2)
//            EditorTabGroupView(tabGroup: StaticTabGroup.demoGroup).frame(width: 100)
        }
        .padding()
    }
}
