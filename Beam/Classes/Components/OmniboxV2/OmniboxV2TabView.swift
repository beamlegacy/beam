//
//  OmniboxV2TabView.swift
//  Beam
//
//  Created by Remi Santos on 01/12/2021.
//

import SwiftUI
import BeamCore

struct OmniboxV2TabView: View {
    static let minimumWidth: CGFloat = 29
    static let pinnedWidth: CGFloat = 32
    static let minimumActiveWidth: CGFloat = 120
    static let height: CGFloat = 29

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tab: BrowserTab
    @State var isHovering = false

    var isSelected: Bool = false
    var isPinned: Bool = false
    var isSingleTab: Bool = false
    var isDragging: Bool = false
    var disableAnimations: Bool = false
    var onClose: (() -> Void)?
    var onCopy: (() -> Void)?
    var onToggleMute: (() -> Void)?

    private let defaultFadeTransition = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
    private let defaultFadeTransitionDelayed = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08).delay(0.03))

    private func shouldShowTitle(geometry: GeometryProxy) -> Bool {
        geometry.size.width >= 80
    }

    private func shouldShowCompactSize(geometry: GeometryProxy) -> Bool {
        geometry.size.width < 60
    }

    private var foregroundColor: Color {
        if isHovering && isSelected {
            return BeamColor.Generic.text.swiftUI
        }
        return BeamColor.Corduroy.swiftUI
    }

    private var font: Font {
        if isSelected {
            return BeamFont.medium(size: 11).swiftUI
        }
        return BeamFont.regular(size: 11).swiftUI
    }

    private var audioIsPlaying: Bool {
        tab.mediaPlayerController?.isPlaying == true
    }

    private var audioView: some View {
        OmniboxV2TabAudioView(tab: tab, action: onToggleMute)
    }

    private var securityIcon: some View {
        let isSecure = tab.url?.scheme == "https"
        let icon = isSecure ? "tabs-security" : "tabs-security_risk"
        let color = isSecure ? BeamColor.AlphaGray : BeamColor.Shiraz
        return Icon(name: icon, color: color.swiftUI).opacity(isSecure ? 1 : 0.4)
    }

    private var displayedTitle: String {
        if isHovering && isSelected, let url = tab.url {
            return url.urlStringWithoutScheme
        }
        return tab.title
    }

    private func leadingViews(shouldShowClose: Bool) -> some View {
        HStack(spacing: 1) {
            if shouldShowClose {
                TabContentIcon(name: "tabs-close_xs", color: BeamColor.LightStoneGray, action: onClose)
            }
            if audioIsPlaying {
                audioView
            }
        }
    }

    private func trailingViews(shouldShowCopy: Bool) -> some View {
        HStack(spacing: 1) {
            if shouldShowCopy {
                TabContentIcon(name: "editor-url_copy", width: 12, action: onCopy)
            }
        }
    }

    private var faviconView: some View {
        OmniboxV2TabFaviconView(favIcon: tab.favIcon, isLoading: tab.isLoading,
                                estimatedLoadingProgress: tab.estimatedLoadingProgress, disableAnimations: isDragging)
    }

    private func centerView(shouldShowSecurity: Bool) -> some View {
        ZStack {
            let isHovering = isEnabled && (isHovering || isDragging)
            let offsetAnimation = BeamAnimation.spring(stiffness: 380, damping: 20)
            let showHoverStyle = isHovering && isSelected && tab.url != nil
            let iconNextToTitle = Group { if shouldShowSecurity { securityIcon } else { faviconView } }
            let iconSpacing: CGFloat = shouldShowSecurity ? 1 : 4
            if isSingleTab {
                // Using hidden texts to make sure the intrinsic size used is the largest of these two layout
                HStack {
                    iconNextToTitle
                    ZStack {
                        Text(tab.url?.urlStringWithoutScheme ?? tab.title)
                        Text(tab.title)
                    }
                }.opacity(0)
            }
            if showHoverStyle {
                HStack(spacing: iconSpacing) {
                    iconNextToTitle
                    Text(tab.url?.urlStringWithoutScheme ?? tab.title)
                }
                .transition(
                    isDragging || disableAnimations ? .identity :
                            .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: 8)).animation(offsetAnimation).combined(with: defaultFadeTransitionDelayed),
                                        removal: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(offsetAnimation).combined(with: defaultFadeTransitionDelayed))
                )
            } else {
                HStack(spacing: iconSpacing) {
                    iconNextToTitle
                    Text(tab.title)
                }
                .transition(
                    isDragging || disableAnimations ? .identity :
                            .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(offsetAnimation).combined(with: defaultFadeTransition),
                                        removal: .animatableOffset(offset: CGSize(width: 0, height: 8)).animation(offsetAnimation).combined(with: defaultFadeTransition))
                )
            }
        }
        .lineLimit(1)
    }

    private func label(isHovering: Bool, containerGeometry: GeometryProxy) -> some View {
        let isHovering = isEnabled && (isHovering || isDragging)
        let shouldShowTitle = shouldShowTitle(geometry: containerGeometry)
        let shouldShowSecurity = isHovering && tab.url != nil && isSelected
        let shouldShowCopy = isHovering && shouldShowTitle && tab.url != nil
        let shouldShowClose = !isPinned && isHovering && !shouldShowCompactSize(geometry: containerGeometry)

        let leadingViews = leadingViews(shouldShowClose: shouldShowClose)
        let trailingViews = trailingViews(shouldShowCopy: shouldShowCopy)
        let showsAnyLeadingView = shouldShowClose || audioIsPlaying
        let showsAnyTrailingView = shouldShowCopy
        return HStack(spacing: 0) {
            if showsAnyLeadingView {
                leadingViews
                .transition(!isSelected ? .identity : .asymmetric(insertion: defaultFadeTransitionDelayed, removal: defaultFadeTransition))
                Spacer(minLength: 4)
            }
            if shouldShowTitle {
                centerView(shouldShowSecurity: shouldShowSecurity)
                    .if(isSingleTab) {
                        $0.frame(maxWidth: containerGeometry.size.width - 60)
                    }
                .layoutPriority(1)
            } else {
                faviconView
            }
            if showsAnyLeadingView || showsAnyTrailingView {
                Spacer(minLength: 4)
                ZStack(alignment: .trailing) {
                    leadingViews.opacity(0).frame(minWidth: 0) // copy leading view on the other size to center content
                    trailingViews
                }
                .transition(!isSelected ? .identity : .asymmetric(insertion: defaultFadeTransitionDelayed, removal: defaultFadeTransition))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fixedSize(horizontal: isSingleTab && !isPinned, vertical: false)
    }

    var body: some View {
        GeometryReader { proxy in
            HStack {
                label(isHovering: isHovering, containerGeometry: proxy)
                    .font(font)
                    .foregroundColor(foregroundColor)
                    .padding(.horizontal, shouldShowCompactSize(geometry: proxy) ? 0 : BeamSpacing._80)
                    .if(!isDragging || colorScheme == .dark) {
                        $0.blendModeLightMultiplyDarkScreen()
                    }
                    .background(
                        // Using Capsule as background instead of Capsule's label property because we have different gestures (drag/click) + paddings
                        // and they don't play well with the rendering updates of the capsule label with parameters.
                        OmniboxV2CapsuleButton(isSelected: false, isForeground: isSelected && (!isSingleTab || isDragging), label: { _, _ in Group { } }, action: nil)
                    )
                    .if(isDragging) {
                        $0.opacity(0.9).scaleEffect(1.07)
                            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 6)
                    }
                    .onHover {
                        isHovering = $0
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

extension OmniboxV2TabView {
    struct TabContentIcon: View {
        var name: String
        var width: CGFloat = 16
        var color = BeamColor.AlphaGray
        var hoveredColor = BeamColor.Corduroy
        var pressedColor = BeamColor.Niobium
        var action: (() -> Void)?

        @State private var isHovering = false
        @State private var isPressed = false

        private var foregroundColor: Color {
            if isPressed {
                return pressedColor.swiftUI
            } else if isHovering {
                return hoveredColor.swiftUI
            }
            return color.swiftUI
        }
        var body: some View {
            Icon(name: name, width: width, color: foregroundColor)
                .onHover { isHovering = $0 }
                .onTouchDown { isPressed = $0 }
                .simultaneousGesture(TapGesture().onEnded {
                    action?()
                })
        }
    }
}

struct OmniboxV2TabView_Previews: PreviewProvider {
    static var state = BeamState()
    static var tab: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: nil)
        t.title = "Tab Title"
        return t
    }()
    static var longTab: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: nil)
        t.title = "Very Very Very Very Very Very Very Very Very Long Tab Even More"
        return t
    }()
    static var tabPlaying: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: nil)
        t.title = "Playing Tab"
        t.mediaPlayerController?.isPlaying = true
        return t
    }()

    static var previews: some View {
        Group {
            ZStack {
                VStack {
                    OmniboxV2TabView(tab: tab, isSelected: true)
                    OmniboxV2TabView(tab: tabPlaying, isSelected: true)
                    OmniboxV2TabView(tab: longTab, isHovering: false, isSelected: false)
                        .frame(width: 70)
                    OmniboxV2TabView(tab: tab, isHovering: true, isSelected: false)
                    OmniboxV2TabView(tab: tab, isSelected: false)
                    OmniboxV2TabView(tab: tabPlaying, isHovering: true, isSelected: false)
                }
                Rectangle().fill(Color.red)
                    .frame(width: 1, height: 280)
            }
            .padding()
            .frame(width: 360)
            .background(BeamColor.AlphaGray.swiftUI)
        }
        .preferredColorScheme(.light)
    }
}
