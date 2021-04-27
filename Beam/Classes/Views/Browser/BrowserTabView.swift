//
//  BroserTabView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct BrowserTabView: View {

    static let minimumWidth: CGFloat = 26
    static let minimumActiveWidth: CGFloat = 120

    @EnvironmentObject var state: BeamState
    @Environment(\.isEnabled) private var isEnabled
    @ObservedObject var tab: BrowserTab
    @State var isHovering = false

    var isSelected: Bool = false
    var isDragging: Bool = false

    private var foregroundColor: Color {
        isSelected ? BeamColor.Corduroy.swiftUI : BeamColor.LightStoneGray.swiftUI
    }

    private var backgroundColor: Color {
        guard !isSelected else { return BeamColor.Generic.background.swiftUI }
        return isHovering ? BeamColor.Mercury.swiftUI : BeamColor.Nero.swiftUI
    }

    private func shouldShowTitle(geometry: GeometryProxy) -> Bool {
        geometry.size.width >= 80
    }

    private func sideSpacing(geometry: GeometryProxy) -> CGFloat {
        let maxSpacing: CGFloat = geometry.size.width > Self.minimumActiveWidth ? 32 : 20
        return min(maxSpacing, (geometry.size.width - 16) / 2)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geometry in
                let sideSpace = sideSpacing(geometry: geometry)
                HStack(alignment: .center, spacing: 0) {
                    Rectangle().fill(Color.clear).frame(width: sideSpace)
                    HStack(alignment: .center, spacing: BeamSpacing._40) {
                        if let icon = tab.favIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        } else {
                            Icon(name: "field-web", size: 16, color: foregroundColor)
                        }

                        if shouldShowTitle(geometry: geometry) {
                            Text(tab.title)
                                .font(BeamFont.medium(size: 11).swiftUI)
                                .foregroundColor(foregroundColor)
                                .lineLimit(1)
                        }
                    }.frame(maxWidth: .infinity)
                    HStack {
                        if isHovering && !isDragging && sideSpace >= 20 {
                            ButtonLabel(icon: "tabs-close_xs", customStyle: ButtonLabelStyle.tinyIconStyle) {
                                closeTab(id: tab.id)
                            }
                            .padding(.horizontal, BeamSpacing._60)
                            .frame(alignment: .trailing)
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15))
                    .frame(width: sideSpace)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor
                                .overlay(Rectangle()
                                            .fill(BeamColor.BottomBar.shadow.swiftUI)
                                            .frame(height: 0.5)
                                            .opacity(isSelected ? 0 : 1.0)
                                            .animation(isDragging ? nil : .easeInOut(duration: 0.15)),
                                         alignment: .top)
                                .overlay(Separator(hairline: true).padding(.vertical, isSelected ? 0 : 7),
                                         alignment: .trailing)
                )
                .onHover { hovering in
                    isHovering = isEnabled && hovering
                }
                .accessibility(identifier: "browserTabBarView")
            }
            if isSelected || isDragging {
                Separator(hairline: true).offset(x: -Separator.hairlineWidth, y: 0)
            }
        }
        .frame(minWidth: isSelected ? Self.minimumActiveWidth : Self.minimumWidth,
               maxWidth: .infinity,
               maxHeight: .infinity)
    }

    func closeTab(id: UUID) {
        for (i, t) in state.tabs.enumerated() where t.id == id {
            if i > 0 {
                state.currentTab = state.tabs[i - 1]
            } else if state.tabs.count > 1 {
                state.currentTab = state.tabs[i + 1]
            } else {
                state.currentTab = nil
                if let note = state.currentNote {
                    state.navigateToNote(note)
                } else {
                    state.navigateToJournal()
                }
            }
            _ = state.removeTab(i)
        }

    }
}

struct BrowserTabView_Previews: PreviewProvider {
    static var state = BeamState()
    static var tab: BrowserTab = {
        let t = BrowserTab(state: state, originalQuery: "", note: BeamNote(title: "test"))
        t.title = "Tab Title"
        return t
    }()
    static var longTab: BrowserTab = {
        let t = BrowserTab(state: state, originalQuery: "", note: BeamNote(title: "test2"))
        t.title = "Very Very Very Very Very Very Very Very Very Long Tab"
        return t
    }()
    static var previews: some View {
            VStack {
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(height: 30)
                BrowserTabView(tab: longTab, isHovering: false, isSelected: false)
                    .frame(height: 30)
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(width: 0, height: 30)
                BrowserTabView(tab: tab, isHovering: true, isSelected: false)
                    .frame(width: 60, height: 30)
                BrowserTabView(tab: tab, isSelected: false)
                    .frame(width: 0, height: 30)
                BrowserTabView(tab: tab, isHovering: true, isSelected: false)
                    .frame(width: 0, height: 30)
            }.padding()
            .frame(width: 360)
            .background(BeamColor.Beam.swiftUI)
    }
}
