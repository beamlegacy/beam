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

    @Environment(\.isEnabled) private var isEnabled
    @ObservedObject var tab: BrowserTab
    @State var isHovering = false

    var isSelected: Bool = false
    var isDragging: Bool = false
    var onClose: (() -> Void)?

    private var foregroundColor: Color {
        isSelected ? BeamColor.Corduroy.swiftUI : BeamColor.LightStoneGray.swiftUI
    }

    private var backgroundColor: Color {
        guard !isSelected else { return BeamColor.Generic.background.swiftUI }
        return isHovering ? BeamColor.Mercury.swiftUI : BeamColor.Nero.swiftUI
    }

    private var audioIsPlaying: Bool {
        tab.mediaPlayerController?.isPlaying == true
    }

    private var audioIsMuted: Bool {
        tab.mediaPlayerController?.isMuted == true
    }

    private var allowsPictureInPicture: Bool {
        tab.allowsPictureInPicture && tab.mediaPlayerController?.isPiPSupported == true
    }

    private func shouldShowTitle(geometry: GeometryProxy) -> Bool {
        geometry.size.width >= 80
    }

    private func shouldShowIcon(geometry: GeometryProxy) -> Bool {
        !audioIsPlaying || geometry.size.width > 72
    }

    private func sideSpacing(geometry: GeometryProxy) -> CGFloat {
        let maxSpacing: CGFloat = geometry.size.width > Self.minimumActiveWidth ? 32 : 20
        let minSpacing: CGFloat = audioIsPlaying && shouldShowIcon(geometry: geometry) ? 28 : 0
        return max(minSpacing, min(maxSpacing, (geometry.size.width - 16) / 2))
    }

    // MARK: Subviews
    private var iconView: some View {
        Group {
            if let icon = tab.favIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Icon(name: "field-web", size: 16, color: foregroundColor)
            }
        }
    }

    private var titleView: some View {
        Text(tab.title)
            .font(BeamFont.medium(size: 11).swiftUI)
            .foregroundColor(foregroundColor)
            .lineLimit(1)
    }

    private func leadingSubviews(sideSpace: CGFloat, showIcon: Bool) -> some View {
        HStack {
            if audioIsPlaying {
                ButtonLabel(icon: audioIsMuted ? "tabs-media_muted" : "tabs-media", customStyle: .tinyIconStyle) {
                    tab.mediaPlayerController?.toggleMute()
                }
                .padding(.horizontal, showIcon ? BeamSpacing._60 : 0)
                .accessibility(identifier: "browserTabMediaIndicator")
                .contextMenu {
                    Button("\(audioIsMuted ? "Unmute" : "Mute") this tab") {
                        tab.mediaPlayerController?.toggleMute()
                    }
                    if allowsPictureInPicture {
                        let isInPip = tab.mediaPlayerController?.isInPiP == true
                        Button("\(isInPip ? "Leave" : "Enter") Picture in Picture") {
                            tab.mediaPlayerController?.togglePiP()
                        }
                    }
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15))
        .frame(width: sideSpace)
    }

    private func trailingSubviews(sideSpace: CGFloat) -> some View {
        HStack {
            if isHovering && !isDragging && sideSpace >= 20 {
                ButtonLabel(icon: "tabs-close_xs", customStyle: ButtonLabelStyle.tinyIconStyle) {
                    onClose?()
                }
                .padding(.horizontal, BeamSpacing._60)
                .frame(alignment: .trailing)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15))
        .frame(width: sideSpace)
    }

    private var backgroundAndBorderView: some View {
        backgroundColor
            .overlay(Rectangle()
                        .fill(BeamColor.BottomBar.shadow.swiftUI)
                        .frame(height: 0.5)
                        .opacity(isSelected ? 0.0 : 1.0)
                        .animation(isDragging ? nil : .easeInOut(duration: 0.15)),
                     alignment: .top)
            .overlay(Separator(hairline: true).padding(.vertical, CGFloat(isSelected ? 0 : 7)),
                     alignment: .trailing)
    }

    // MARK: Main View
    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geometry in
                let sideSpace = sideSpacing(geometry: geometry)
                let showTitle = shouldShowTitle(geometry: geometry)
                let showIcon = shouldShowIcon(geometry: geometry)
                HStack(alignment: .center, spacing: 0) {
                    leadingSubviews(sideSpace: sideSpace, showIcon: showIcon)
                    if showTitle || showIcon {
                        HStack(alignment: .center, spacing: BeamSpacing._40) {
                            if showIcon {
                                iconView
                            }
                            if showTitle {
                               titleView
                            }
                        }.frame(maxWidth: .infinity)
                    }
                    if showIcon {
                        trailingSubviews(sideSpace: sideSpace)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundAndBorderView)
                .onHover { hovering in
                    isHovering = isEnabled && hovering
                }
                .accessibilityElement(children: .contain)
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
}

struct BrowserTabView_Previews: PreviewProvider {
    static var state = BeamState()
    static var tab: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: BeamNote(title: "test"))
        t.title = "Tab Title"
        t.mediaPlayerController?.isPlaying = true
        return t
    }()
    static var longTab: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: BeamNote(title: "test2"))
        t.title = "Very Very Very Very Very Very Very Very Very Long Tab"
        return t
    }()
    static var tabPlaying: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: BeamNote(title: "test3"))
        t.title = "Playing Tab"
        t.mediaPlayerController?.isPlaying = true
        return t
    }()

    static var previews: some View {
        ZStack {
            VStack {
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(height: 30)
                BrowserTabView(tab: longTab, isHovering: false, isSelected: false)
                    .frame(height: 30)
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(width: 0, height: 30)
                BrowserTabView(tab: tabPlaying, isSelected: true)
                    .frame(width: 0, height: 30)
                BrowserTabView(tab: tab, isHovering: true, isSelected: false)
                    .frame(width: 60, height: 30)
                BrowserTabView(tab: tab, isSelected: false)
                    .frame(width: 0, height: 30)
                BrowserTabView(tab: tabPlaying, isHovering: true, isSelected: false)
                    .frame(width: 0, height: 30)
            }
            Rectangle().fill(Color.red)
                .frame(width: 1, height: 280)
        }.padding()
            .frame(width: 360)
            .background(BeamColor.Beam.swiftUI)
    }
}
