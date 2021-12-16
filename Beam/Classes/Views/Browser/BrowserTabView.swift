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
    static let pinnedWidth: CGFloat = 36
    static let minimumActiveWidth: CGFloat = 120
    static let separatorColor = BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.4, darkColor: .AlphaGray, darkAlpha: 0.8)
    static let activeTabSeparatorColor = BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.5, darkColor: .Mercury)

    @Environment(\.isEnabled) private var isEnabled
    @ObservedObject var tab: BrowserTab
    @State var isHovering = false

    var isSelected: Bool = false
    var isDragging: Bool = false
    var allowHover: Bool = true
    var designV2: Bool = false
    var onClose: (() -> Void)?

    private var displayHoverStyle: Bool {
        allowHover && isHovering && isEnabled
    }
    private var foregroundColor: Color {
        displayHoverStyle ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI
    }

    private var iconForegroundColor: Color {
        isSelected ? foregroundColor : BeamColor.Corduroy.swiftUI
    }

    private var separatorColor: BeamColor {
        isSelected ? Self.activeTabSeparatorColor : Self.separatorColor
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
        let maxSpacing: CGFloat = geometry.size.width > Self.minimumActiveWidth ? 24 : 20
        let minSpacing: CGFloat = audioIsPlaying && shouldShowIcon(geometry: geometry) ? 28 : 0
        return max(minSpacing, min(maxSpacing, (geometry.size.width - 16) / 2))
    }

    // MARK: Subviews
    private var iconView: some View {
        ZStack {
            if tab.isLoading {
                loadingIndicator
                    .transition(.scale)
            }
            Group {
                if let icon = tab.favIcon {
                    let iconSize: CGFloat = tab.isLoading ? 10 : 16
                    Image(nsImage: icon).resizable().scaledToFit()
                        .cornerRadius(tab.isLoading ? iconSize / 2 : 0)
                        .frame(width: iconSize, height: iconSize)
                } else {
                    let iconSize: CGFloat = tab.isLoading ? 12 : 16
                    Icon(name: "field-web", width: iconSize, color: foregroundColor)
                }
            }
        }
        .animation(nil, value: displayHoverStyle)
        .animation(isDragging ? nil : BeamAnimation.spring(stiffness: 380, damping: 20), value: tab.isLoading)
    }

    @State private var loadingIndicatorAnimatedFlag = false
    private var loadingForeverAnimation: Animation {
        Animation.linear(duration: 1.0)
            .repeatForever(autoreverses: false)
    }

    private var loadingIndicator: some View {
        Circle()
            .trim(from: 0.0, to: CGFloat(tab.estimatedLoadingProgress))
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16)
            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            .rotationEffect(Angle(degrees: self.loadingIndicatorAnimatedFlag ? 360.0 : 0.0))
            .animation(loadingForeverAnimation, value: self.loadingIndicatorAnimatedFlag)
            .animation(BeamAnimation.easeInOut(duration: 0.15), value: tab.estimatedLoadingProgress)
            .onReceive(tab.$isLoading, perform: { _ in
                self.loadingIndicatorAnimatedFlag.toggle()
            })
    }

    private var titleView: some View {
        Text(tab.title)
            .font(BeamFont.regular(size: 11).swiftUI)
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
        .animation(BeamAnimation.easeInOut(duration: 0.15), value: audioIsPlaying)
        .frame(width: sideSpace)
    }

    static let activeTabCloseIconStyle = ButtonLabelStyle.tinyIconStyle
    static let otherTabCloseIconStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle.tinyIconStyle
        style.foregroundColor = BeamColor.Corduroy.swiftUI
        style.activeForegroundColor = BeamColor.Niobium.swiftUI
        style.hoveredBackgroundColor = BeamColor.AlphaGray.swiftUI
        style.activeBackgroundColor = BeamColor.LightStoneGray.swiftUI
        return style
    }()

    private func trailingSubviews(sideSpace: CGFloat) -> some View {
        HStack {
            if displayHoverStyle && !isDragging && sideSpace >= 20 {
                ButtonLabel(icon: "tabs-close_xs", customStyle: isSelected ? Self.activeTabCloseIconStyle : Self.otherTabCloseIconStyle) {
                    onClose?()
                }
                .padding(.trailing, BeamSpacing._60)
                .frame(alignment: .trailing)
            }
        }
        .transition(.opacity)
        .animation(BeamAnimation.easeInOut(duration: 0.15))
        .frame(width: sideSpace)
    }

    private var backgroundAndBorderView: some View {
        BrowserTabView.BackgroundView(isSelected: isSelected, isHovering: displayHoverStyle)
            .if(designV2 && !isDragging) {
                $0.opacity(isSelected ? 0.5 : 0)
            }
            .overlay(Separator(hairline: true, color: separatorColor)
                        .padding(.vertical, CGFloat(isSelected ? 0 : 7)),
                     alignment: .trailing)
            .shadow(color: BeamColor.ToolBar.shadowBottom.swiftUI.opacity(isDragging ? 1 : 0), radius: 8, x: 0, y: 2)

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
                .onHover { isHovering = $0 }
                .animation(BeamAnimation.easeInOut(duration: 0.15), value: displayHoverStyle)
                .accessibilityElement(children: .contain)
                .accessibility(identifier: "browserTabBarView")
            }

            if isSelected || isDragging {
                Separator(hairline: true, color: separatorColor)
                    .background(BeamColor.Generic.background.swiftUI)
                    .offset(x: -Separator.hairlineWidth, y: 0)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    struct BackgroundView: View {

        var isSelected: Bool
        var isHovering: Bool

        private var backgroundColor: Color {
            guard !isSelected else { return BeamColor.Generic.background.swiftUI }
            return BeamColor.ToolBar.secondaryBackground.swiftUI
        }

        private var additionalBackgroundColor: Color? {
            guard !isSelected && isHovering else { return nil }
            return BeamColor.ToolBar.hoveredSecondaryAdditionalBackground.swiftUI
        }

        var body: some View {
            backgroundColor
                .overlay(additionalBackgroundColor)
                .overlay(Rectangle()
                            .fill(BeamColor.ToolBar.shadowTop.swiftUI)
                            .frame(height: Separator.hairlineHeight)
                            .opacity(isSelected ? 0.0 : 1.0),
                         alignment: .top)
                .overlay(Rectangle()
                            .fill(BeamColor.ToolBar.shadowBottom.swiftUI)
                            .frame(height: Separator.hairlineHeight),
                         alignment: .bottom)
        }
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
        t.title = "Very Very Very Very Very Very Very Very Very Long Tab Even More"
        return t
    }()
    static var tabPlaying: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: BeamNote(title: "test3"))
        t.title = "Playing Tab"
        t.mediaPlayerController?.isPlaying = true
        return t
    }()

    static let tabHeight: CGFloat = 30
    static var previews: some View {
        ZStack {
            VStack {
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(height: tabHeight)
                BrowserTabView(tab: longTab, isHovering: false, isSelected: false)
                    .frame(height: tabHeight)
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(width: 0, height: tabHeight)
                BrowserTabView(tab: tabPlaying, isSelected: true)
                    .frame(width: 0, height: tabHeight)
                BrowserTabView(tab: tab, isHovering: true, isSelected: false)
                    .frame(width: 60, height: tabHeight)
                BrowserTabView(tab: tab, isSelected: false)
                    .frame(width: 0, height: tabHeight)
                BrowserTabView(tab: tabPlaying, isHovering: true, isSelected: false)
                    .frame(width: 0, height: tabHeight)
            }
            Rectangle().fill(Color.red)
                .frame(width: 1, height: 280)
        }
        .padding()
        .frame(width: 360)
        .background(BeamColor.Generic.background.swiftUI)
    }
}
