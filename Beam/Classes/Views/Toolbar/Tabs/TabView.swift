//
//  TabView.swift
//  Beam
//
//  Created by Remi Santos on 01/12/2021.
//
// swiftlint:disable file_length
import SwiftUI
import BeamCore

struct TabView: View {
    static let minimumWidth: CGFloat = 29
    static let pinnedWidth: CGFloat = 32
    static let minimumActiveWidth: CGFloat = 120
    static let height: CGFloat = 29
    private static let minSingleTabWidth: Double = 350

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var tab: BrowserTab
    @State var isHovering = false

    var isSelected: Bool = false
    var isPinned: Bool = false
    var isSingleTab: Bool = false
    var isDragging: Bool = false
    var disableAnimations: Bool = false
    var disableHovering: Bool = false
    var hueTint: Double?
    var onTouchDown: (() -> Void)?
    var onTap: (() -> Void)?
    var onClose: (() -> Void)?
    var onCopy: (() -> Void)?
    var onToggleMute: (() -> Void)?

    private let localCoordinateSpaceName = "TabCoordinateSpace"
    private let defaultFadeTransition = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
    private let defaultFadeTransitionDelayed = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08).delay(0.03))
    private var sideViewsTransition: AnyTransition {
        !isSelected ? .identity : .asymmetric(insertion: defaultFadeTransitionDelayed, removal: defaultFadeTransition)
    }

    private func shouldShowTitle(geometry: GeometryProxy) -> Bool {
        geometry.size.width >= 100
    }

    private func shouldShowCompactSize(geometry: GeometryProxy) -> Bool {
        geometry.size.width < 60
    }

    private var foregroundColor: Color {
        if let hueTint = hueTint {
            return Color(hue: hueTint, saturation: 0.6, brightness: 0.5)
        }
        if isSelected {
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

    private var copyMessage: String? {
        tab.hasCopiedURL ? loc("Link Copied") : nil
    }

    private var audioView: some View {
        TabAudioView(tab: tab, action: onToggleMute)
    }

    private var securityIcon: some View {
        // hasOnlySecureContent is KVO observable, may be we should subscribe to it to reflect dynamic changes to it accordingly
        let isSecure = tab.webView.hasOnlySecureContent
        let icon = isSecure ? "tabs-security" : "tabs-security_risk"
        let color = isSecure ? BeamColor.AlphaGray : BeamColor.Shiraz
        return Icon(name: icon, color: color.swiftUI).opacity(isSecure ? 1 : 0.4)
    }

    private func leadingViews(shouldShowClose: Bool) -> some View {
        HStack(spacing: 1) {
            if shouldShowClose {
                closeIcon
            }
        }
    }

    private func estimatedTrailingViewsWidth(shouldShowCopy: Bool, shouldShowMedia: Bool) -> CGFloat {
        let intericonSpacing = BeamSpacing._60
        let trailingViewLeadingPadding = BeamSpacing._40
        return (shouldShowCopy ? 12 : 0) + (shouldShowMedia ? 16 : 0)
        + (shouldShowCopy && shouldShowMedia ? intericonSpacing : 0)
        + (shouldShowCopy || shouldShowMedia ? trailingViewLeadingPadding : 0)
    }
    private func trailingViews(shouldShowCopy: Bool, shouldShowMedia: Bool) -> some View {
        return HStack(spacing: BeamSpacing._60) {
            if shouldShowCopy {
                TabContentIcon(name: "editor-url_copy", width: 12, action: onCopy)
                    .transition(sideViewsTransition)
            }
            if shouldShowMedia {
                audioView
                    .transition(sideViewsTransition)
            }
        }
    }

    private var faviconView: some View {
        TabFaviconView(
            favIcon: faviconImage,
            isLoading: tab.isLoading,
            estimatedLoadingProgress: tab.estimatedLoadingProgress,
            disableAnimations: isDragging
        ).allowsHitTesting(false)
    }

    private var faviconImage: NSImage? {
        switch tab.contentType {
        case .web:
            return tab.favIcon

        case .pdf:
            return NSImage(named: "tabs-file")?.fill(color: BeamColor.LightStoneGray.nsColor)
        }
    }

    private var closeIcon: some View {
        TabContentIcon(name: "tabs-close_xs", color: BeamColor.LightStoneGray, action: onClose)
    }

    private func centerViewTransition(foregroundHoverStyle: Bool) -> AnyTransition {
        guard !isDragging && !disableAnimations else {
            return .identity
        }
        let offsetAnimation = BeamAnimation.spring(stiffness: 380, damping: 20)
        if foregroundHoverStyle {
            return .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: 8)).animation(offsetAnimation).combined(with: defaultFadeTransitionDelayed),
                               removal: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(offsetAnimation).combined(with: defaultFadeTransitionDelayed))
        } else {
            return .asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: -8)).animation(offsetAnimation).combined(with: defaultFadeTransition),
                               removal: .animatableOffset(offset: CGSize(width: 0, height: 8)).animation(offsetAnimation).combined(with: defaultFadeTransition))
        }
    }

    private func copyMessageView(message: String) -> some View {
        HStack(spacing: BeamSpacing._40) {
            Icon(name: "editor-url_copy", width: 12, color: BeamColor.LightStoneGray.swiftUI)
            Text(message)
                .font(BeamFont.medium(size: 11).swiftUI)
                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                .allowsHitTesting(false)
                .accessibility(identifier: "browserTabInfoMessage")
        }
    }

    private func centerViewDefaultContent(shouldShowSecurity: Bool, shouldShowClose: Bool,
                                          leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat) -> some View {
        let iconSpacing = iconTitleSpacing(shouldShowSecurity: shouldShowSecurity)
        return HStack(spacing: iconSpacing) {
            iconNextToTitle(shouldShowSecurity: shouldShowSecurity)
            Text(tab.title)
                .accessibility(identifier: "browserTabTitle")
                .allowsHitTesting(false)
        }
        .if(isSingleTab) {
            $0.frame(minWidth: Self.minSingleTabWidth)
        }
        .if(!isSingleTab) {
            $0.opacity(0).overlay(GeometryReader { proxy in
                let spaceAroundTitle = proxy.frame(in: .named(localCoordinateSpaceName)).minX
                let hasEnoughSpaceForClose = spaceAroundTitle >= leadingViewsWidth
                HStack(spacing: iconSpacing) {
                    iconNextToTitle(shouldShowSecurity: shouldShowSecurity)
                        .opacity(shouldShowClose && !hasEnoughSpaceForClose ? 0 : 1)
                    Text(tab.title)
                        .padding(.trailing, max(0, trailingViewsWidth - spaceAroundTitle))
                        .allowsHitTesting(false)
                        .accessibility(identifier: "browserTabTitle")
                }
            }, alignment: .leading)
        }
    }

    private func centerViewForegroundHoverContent(shouldShowSecurity: Bool, shouldShowClose: Bool,
                                                  leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat) -> some View {
        let iconSpacing = iconTitleSpacing(shouldShowSecurity: shouldShowSecurity)
        let urlString = tab.url?.urlStringWithoutScheme ?? tab.title
        let iconTitleContent = HStack(spacing: iconSpacing) {
            iconNextToTitle(shouldShowSecurity: shouldShowSecurity)
            Text(urlString)
                .allowsHitTesting(false)
                .accessibility(identifier: "browserTabURL")
        }
        return Group {
            if isSingleTab {
                // single tab width should be max(tabTitleWidth, minSingleTabWidth).
                // Using overlay over unhover content to produce this layout.
                centerViewDefaultContent(shouldShowSecurity: false, shouldShowClose: false,
                                         leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth)
                    .frame(minWidth: Self.minSingleTabWidth)
                    .opacity(0)
                    .overlay(GeometryReader { proxy in
                        iconTitleContent
                            .frame(width: max(proxy.size.width, Self.minSingleTabWidth))
                            .offset(x: -(Self.minSingleTabWidth - min(Self.minSingleTabWidth, proxy.size.width)) / 2, y: 0)
                    })
            } else {
                iconTitleContent
            }
        }
    }

    private func iconNextToTitle(shouldShowSecurity: Bool) -> some View {
        Group {
            if shouldShowSecurity {
                securityIcon
            } else {
                faviconView
            }
        }
    }

    private func iconTitleSpacing(shouldShowSecurity: Bool) -> Double {
        shouldShowSecurity ? 1 : BeamSpacing._40
    }

    private func centerView(shouldShowSecurity: Bool, leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat) -> some View {
        ZStack {
            let isHovering = isEnabled && !disableHovering && (isHovering || isDragging)
            let showForegroundHoverStyle = isHovering && isSelected
            let shouldShowClose = isHovering
            if let copyMessage = copyMessage {
                copyMessageView(message: copyMessage)
                    .transition(centerViewTransition(foregroundHoverStyle: true))
            } else if showForegroundHoverStyle {
                centerViewForegroundHoverContent(shouldShowSecurity: shouldShowSecurity, shouldShowClose: shouldShowClose,
                                                 leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth)
                    .transition(centerViewTransition(foregroundHoverStyle: true))
            } else {
                centerViewDefaultContent(shouldShowSecurity: shouldShowSecurity, shouldShowClose: shouldShowClose,
                                         leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth)
                    .transition(centerViewTransition(foregroundHoverStyle: false))
            }
        }
        .lineLimit(1)
    }

    // swiftlint:disable function_body_length
    ///  Layout of leading views, title and trailing views together.
    ///
    ///  To maintain a perfectly centered title
    ///  and have no jumps between different hover and animation states,
    ///  we often need to display a hidden version of leading or trailing views.
    private func content(isHovering: Bool, containerGeometry: GeometryProxy) -> some View {
        let isHovering = isEnabled && !disableHovering && (isHovering || isDragging)
        let shouldShowTitle = shouldShowTitle(geometry: containerGeometry)
        let shouldShowSecurity = isHovering && tab.url != nil && isSelected
        let shouldShowCopy = isHovering && shouldShowTitle && tab.url != nil
        let shouldShowCompactSize = shouldShowCompactSize(geometry: containerGeometry)
        let shouldShowClose = !isPinned && isHovering && !shouldShowCompactSize
        let shouldShowMedia = !shouldShowCompactSize && audioIsPlaying
        let showForegroundHoverStyle = isHovering && isSelected
        let hPadding = shouldShowCompactSize ? 0 : BeamSpacing._80

        let leadingViews = leadingViews(shouldShowClose: shouldShowClose)
        let trailingViews = trailingViews(shouldShowCopy: shouldShowCopy, shouldShowMedia: shouldShowMedia)
        var estimatedTrailingViewsWidth: CGFloat = 0
        if !showForegroundHoverStyle {
            estimatedTrailingViewsWidth = hPadding + self.estimatedTrailingViewsWidth(shouldShowCopy: shouldShowCopy, shouldShowMedia: shouldShowMedia)
        }
        let estimatedLeadingViewsWidth: CGFloat = hPadding + (shouldShowClose ? 16 : 0)
        return HStack(spacing: 0) {

            // Leading Content
            if showForegroundHoverStyle {
                leadingViews.transition(sideViewsTransition).padding(.leading, hPadding)
                Spacer(minLength: BeamSpacing._40)
            } else if isSingleTab {
                ZStack {
                    // make space for the non-active-single hover style
                    self.leadingViews(shouldShowClose: true).opacity(0).accessibility(hidden: true)
                    leadingViews.transition(sideViewsTransition)
                }
                .padding(.leading, hPadding)
                Spacer(minLength: BeamSpacing._40)
            } else {
                Rectangle().fill(Color.clear).frame(minWidth: hPadding)
                    .overlay(
                        leadingViews.transition(sideViewsTransition).padding(.leading, hPadding),
                        alignment: .leading
                    )
            }

            // Center Content
            if shouldShowTitle {
                centerView(shouldShowSecurity: shouldShowSecurity, leadingViewsWidth: estimatedLeadingViewsWidth, trailingViewsWidth: estimatedTrailingViewsWidth)
                    .layoutPriority(2)
            } else if shouldShowCompactSize && audioIsPlaying {
                audioView
            } else {
                faviconView
            }

            // Trailing Content
            if showForegroundHoverStyle || isSingleTab {
                Spacer(minLength: BeamSpacing._40)
            }
            ZStack {
                if showForegroundHoverStyle {
                    // make space for the active hover style
                    trailingViews.padding(.trailing, hPadding).opacity(0)
                } else if isSingleTab {
                    // make space for the non-active-single hover style
                    self.trailingViews(shouldShowCopy: true, shouldShowMedia: shouldShowMedia)
                        .padding(.trailing, hPadding).opacity(0).accessibilityHidden(true)
                } else {
                    Rectangle().fill(Color.clear)
                        .frame(minWidth: hPadding)
                }
            }
            .overlay(ZStack {
                trailingViews
            }.padding(.trailing, hPadding), alignment: .trailing)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fixedSize(horizontal: isSingleTab && !isPinned, vertical: false)
        .coordinateSpace(name: localCoordinateSpaceName)
    }

    var body: some View {
        GeometryReader { proxy in
            HStack {
                content(isHovering: isHovering, containerGeometry: proxy)
                    .font(font)
                    .foregroundColor(foregroundColor)
                    .if(!isDragging || colorScheme == .dark) {
                        $0.blendModeLightMultiplyDarkScreen()
                    }
                    .background(
                        // Using Capsule as background instead of Capsule's label property because we have different gestures (drag/click) + paddings
                        // and they don't play well with the rendering updates of the capsule label with parameters.
                        ToolbarCapsuleButton(isSelected: false, isForeground: isSelected,
                                             tabStyle: true, hueTint: hueTint,
                                             label: { _, _ in Group { } }, action: nil)
                            .onTouchDown { down in
                                if down { onTouchDown?() }
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                onTap?()
                            })
                    )
                    .background(!isSingleTab || isDragging ? nil : GeometryReader { prxy in
                        Color.clear.preference(key: SingleTabGlobalFrameKey.self, value: prxy.safeTopLeftGlobalFrame(in: nil).rounded())
                    })
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

struct TabView_Previews: PreviewProvider {
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
    static var tabCopied: BrowserTab = {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: nil)
        t.title = "Tab Copied"
        t.hasCopiedURL = true
        return t
    }()

    static var previews: some View {
        Group {
            ZStack {
                VStack {
                    TabView(tab: tab, isSelected: true)
                    TabView(tab: tabPlaying, isSelected: true)
                    TabView(tab: longTab, isHovering: false, isSelected: false)
                        .frame(width: 70)
                    TabView(tab: tab, isHovering: true, isSelected: false)
                    TabView(tab: tab, isSelected: false)
                    TabView(tab: tabPlaying, isHovering: true, isSelected: false)
                    TabView(tab: tabCopied, isHovering: false, isSelected: false)
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
