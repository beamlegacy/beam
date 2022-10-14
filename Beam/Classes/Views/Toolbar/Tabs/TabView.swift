//
//  TabView.swift
//  Beam
//
//  Created by Remi Santos on 01/12/2021.
//

import BeamCore
import SwiftUI
import UniformTypeIdentifiers

protocol TabViewDelegate {
    func tabDidTouchDown(_ tab: BrowserTab)
    func tabDidTap(_ tab: BrowserTab, isRightMouse: Bool, event: NSEvent?)
    func tabWantsToClose(_ tab: BrowserTab)
    func tabWantsToCopy(_ tab: BrowserTab)
    func tabDidToggleMute(_ tab: BrowserTab)
    func tabWantsToDetach(_ tab: BrowserTab)

    func tabDidReceiveFileDrop(_ tab: BrowserTab, url: URL)
    func tabSupportsFileDrop(_ tab: BrowserTab) -> Bool
}

struct TabView: View {
    static let minimumWidth: CGFloat = 29
    static let maximumWidth: Double = 800 // for very wide screens BE-4571
    static let pinnedWidth: CGFloat = 32
    static let pinnedWidthWithMedia: CGFloat = 52
    static let minimumActiveWidth: CGFloat = 120
    static let minSingleTabWidth: Double = 370
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
    var disableHovering: Bool = false
    var applyDraggingStyle: Bool = true
    var hueTint: Double?
    var isInMainWindow = true
    var delegate: TabViewDelegate?

    private let localCoordinateSpaceName = "TabCoordinateSpace"
    private let defaultFadeTransition = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08))
    private let defaultFadeTransitionDelayed = AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08).delay(0.03))
    private var sideViewsTransition: AnyTransition {
        !isSelected ? .identity : .asymmetric(insertion: defaultFadeTransitionDelayed, removal: defaultFadeTransition)
    }
    private var isIncognito: Bool {
        tab.state?.isIncognito == true
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
            return BeamColor.Generic.text.inverted(isIncognito).swiftUI
        }
        return BeamColor.Corduroy.swiftUI
    }

    private var font: Font {
        if isSelected {
            return BeamFont.medium(size: 11).swiftUI
        }
        return BeamFont.regular(size: 11).swiftUI
    }

    private var mediaIsPlaying: Bool {
        tab.mediaPlayerController?.isPlaying == true && !isDragging
    }

    private var isDetachable: Bool {
        tab.isDetachable
    }

    private var hasTrailingIcon: Bool {
        isDetachable || mediaIsPlaying
    }

    private var copyMessage: String? {
        tab.hasCopiedURL ? loc("Link Copied") : nil
    }

    @ViewBuilder
    private var mainTrailingIconView: some View {
        if isDetachable {
            TabContentIcon(name: "side-detach", width: 12,
                           invertedColors: isIncognito && isSelected,
                           action: onDetach)
                .frame(width: 16, height: 16)
        } else if mediaIsPlaying {
            mediaView
        }
    }

    private var mediaView: some View {
        TabAudioView(tab: tab, invertedColors: isSelected && isIncognito, action: onToggleMute)
    }

    private var securityIcon: some View {
        // hasOnlySecureContent is KVO observable, may be we should subscribe to it to reflect dynamic changes to it accordingly
        let isSecure = tab.webView.hasOnlySecureContent
        let icon = isSecure ? "tabs-security" : "tabs-security_risk"
        let color: BeamColor
        let inverted = isIncognito && isSelected
        if isSecure {
            color = BeamColor.AlphaGray.inverted(inverted)
        } else {
            color = BeamColor.Shiraz.inverted(inverted)
        }
        let opacity = isSecure ? 1 : (colorScheme == .dark ? 0.6 : 0.4)
        return Icon(name: icon, color: color.swiftUI).opacity(opacity)
    }

    private func leadingViews(shouldShowClose: Bool) -> some View {
        HStack(spacing: 1) {
            if shouldShowClose {
                closeIcon
            }
        }
    }

    private func estimatedTrailingViewsWidth(shouldShowCopy: Bool, shouldShowTrailingIcon: Bool) -> CGFloat {
        let intericonSpacing = BeamSpacing._60
        let trailingViewLeadingPadding = BeamSpacing._40
        return (shouldShowCopy ? 12 : 0) + (shouldShowTrailingIcon ? 16 : 0)
        + (shouldShowCopy && shouldShowTrailingIcon ? intericonSpacing : 0)
        + (shouldShowCopy || shouldShowTrailingIcon ? trailingViewLeadingPadding : 0)
    }

    private func trailingViews(shouldShowCopy: Bool, shouldShowTrailingIcon: Bool) -> some View {
        return HStack(spacing: BeamSpacing._60) {
            if shouldShowCopy {
                TabContentIcon(name: "editor-url_copy",
                               width: 12,
                               invertedColors: isIncognito && isSelected,
                               action: onCopy)
                    .transition(sideViewsTransition)
            }
            if shouldShowTrailingIcon {
                mainTrailingIconView
                    .transition(sideViewsTransition)
            }
        }
    }

    private var faviconView: some View {
        TabFaviconView(
            favIcon: faviconImage,
            iconName: tab.contentType == .pdf ? "tabs-file" : nil,
            showGrayScale: !isInMainWindow,
            invertedColors: isSelected && isIncognito,
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
            return nil
        }
    }

    @ViewBuilder private var closeIcon: some View {
        let invert = isIncognito && isSelected
        TabContentIcon(name: "tabs-close_xs",
                       invertedColors: invert,
                       action: onClose)
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

    private func centerViewContent(foregroundHoverStyle: Bool,
                                   shouldShowSecurity: Bool, shouldShowClose: Bool,
                                   leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat, containerWidth: CGFloat) -> some View {
        var minWidth: CGFloat = 0
        if isSingleTab {
            let availableWidth = (containerWidth - leadingViewsWidth - trailingViewsWidth)
            let defaultMinWidth = Self.minSingleTabWidth - leadingViewsWidth - trailingViewsWidth
            minWidth = min(defaultMinWidth, availableWidth)
        }
        return Group {
            if foregroundHoverStyle {
                centerViewForegroundHoverContent(shouldShowSecurity: shouldShowSecurity, shouldShowClose: shouldShowClose,
                                                 leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth, minWidth: minWidth)
            } else {
                centerViewDefaultContent(shouldShowSecurity: shouldShowSecurity, shouldShowClose: shouldShowClose,
                                         leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth, minWidth: minWidth)
            }
        }
    }

    private func centerViewDefaultContent(shouldShowSecurity: Bool, shouldShowClose: Bool,
                                          leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat, minWidth: CGFloat) -> some View {
        let iconSpacing = iconTitleSpacing(shouldShowSecurity: shouldShowSecurity)
        return HStack(spacing: iconSpacing) {
            iconNextToTitle(shouldShowSecurity: shouldShowSecurity)
            Text(tab.title)
                .accessibility(identifier: "browserTabTitle")
                .allowsHitTesting(false)
        }
        .frame(minWidth: isSingleTab ? minWidth : 0)
        .accessibility(hidden: !isSingleTab)
        .opacity(isSingleTab ? 1 : 0).overlay(isSingleTab ? nil : GeometryReader { proxy in
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

    private func centerViewForegroundHoverContent(shouldShowSecurity: Bool, shouldShowClose: Bool,
                                                  leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat, minWidth: CGFloat) -> some View {
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
                // single tab width should be max(tabTitleWidth, minSingleTabContentWidth).
                // Using overlay over unhover content to produce this layout.
                centerViewDefaultContent(shouldShowSecurity: false, shouldShowClose: false,
                                         leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth, minWidth: minWidth)
                    .frame(minWidth: minWidth)
                    .opacity(0)
                    .overlay(GeometryReader { proxy in
                        iconTitleContent
                            .frame(width: max(proxy.size.width, minWidth))
                            .offset(x: -(minWidth - min(minWidth, proxy.size.width)) / 2, y: 0)
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

    private func centerView(shouldShowSecurity: Bool, leadingViewsWidth: CGFloat, trailingViewsWidth: CGFloat, containerWidth: CGFloat) -> some View {
        ZStack {
            let isHovering = isEnabled && !disableHovering && (isHovering || isDragging)
            let showForegroundHoverStyle = isHovering && isSelected
            let shouldShowClose = isHovering
            let base = centerViewContent(foregroundHoverStyle: showForegroundHoverStyle,
                                         shouldShowSecurity: shouldShowSecurity, shouldShowClose: shouldShowClose,
                                         leadingViewsWidth: leadingViewsWidth, trailingViewsWidth: trailingViewsWidth, containerWidth: containerWidth)
            if let copyMessage = copyMessage {
                base
                    .opacity(0)
                    .overlay(copyMessageView(message: copyMessage).fixedSize(horizontal: true, vertical: false))
                    .transition(centerViewTransition(foregroundHoverStyle: true))
            } else if showForegroundHoverStyle {
                base
                    .transition(centerViewTransition(foregroundHoverStyle: true))
            } else {
                base
                    .transition(centerViewTransition(foregroundHoverStyle: false))
            }
        }
        .lineLimit(1)
    }

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
        let shouldShowTrailingIcon = !shouldShowCompactSize && hasTrailingIcon
        let showForegroundHoverStyle = isHovering && isSelected
        let hPadding = shouldShowCompactSize ? 0 : BeamSpacing._80
        let spacerMinWidth = BeamSpacing._40
        let isCompactWithTrailingIcon = shouldShowTrailingIcon && shouldShowCompactSize

        let leadingViews = leadingViews(shouldShowClose: shouldShowClose)
        let trailingViews = trailingViews(shouldShowCopy: shouldShowCopy, shouldShowTrailingIcon: shouldShowTrailingIcon)
        var estimatedTrailingViewsWidth: CGFloat = 0
        if isSingleTab {
            estimatedTrailingViewsWidth = hPadding + self.estimatedTrailingViewsWidth(shouldShowCopy: true, shouldShowTrailingIcon: shouldShowTrailingIcon)
        } else if !showForegroundHoverStyle {
            estimatedTrailingViewsWidth = hPadding + self.estimatedTrailingViewsWidth(shouldShowCopy: shouldShowCopy, shouldShowTrailingIcon: shouldShowTrailingIcon)
        }
        let estimatedLeadingViewsWidth: CGFloat = hPadding + (shouldShowClose || isSingleTab ? 16 : 0) + (isSingleTab ? spacerMinWidth : 0)
        return HStack(spacing: 0) {

            // Leading Content
            if showForegroundHoverStyle {
                leadingViews.transition(sideViewsTransition).padding(.leading, hPadding)
                Spacer(minLength: spacerMinWidth)
            } else if isSingleTab {
                ZStack {
                    // make space for the non-active-single hover style
                    self.leadingViews(shouldShowClose: true).opacity(0).accessibility(hidden: true)
                    leadingViews.transition(sideViewsTransition)
                }
                .padding(.leading, hPadding)
                Spacer(minLength: spacerMinWidth)
            } else {
                Rectangle().fill(Color.clear).frame(minWidth: hPadding)
                    .overlay(
                        leadingViews.transition(sideViewsTransition).padding(.leading, hPadding),
                        alignment: .leading
                    )
            }

            // Center Content
            if shouldShowTitle {
                centerView(shouldShowSecurity: shouldShowSecurity, leadingViewsWidth: estimatedLeadingViewsWidth, trailingViewsWidth: estimatedTrailingViewsWidth, containerWidth: containerGeometry.size.width)
                    .layoutPriority(2)
            } else {
                HStack(spacing: BeamSpacing._40) {
                    if !isCompactWithTrailingIcon || isPinned {
                        faviconView
                    }
                    if isCompactWithTrailingIcon {
                        mainTrailingIconView
                    }
                }
            }

            // Trailing Content
            if showForegroundHoverStyle || isSingleTab {
                Spacer(minLength: spacerMinWidth)
            }
            ZStack {
                if showForegroundHoverStyle {
                    // make space for the active hover style
                    trailingViews.padding(.trailing, hPadding).opacity(0)
                } else if isSingleTab {
                    // make space for the non-active-single hover style
                    self.trailingViews(shouldShowCopy: true, shouldShowTrailingIcon: shouldShowTrailingIcon)
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
        .frame(maxWidth: isSingleTab ? containerGeometry.size.width : .infinity, maxHeight: .infinity)
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
                        $0.blendModeLightMultiplyDarkScreen(invert: isIncognito && isSelected)
                    }
                    .background(
                        // Using Capsule as background instead of Capsule's label property because we have different gestures (drag/click) + paddings
                        // and they don't play well with the rendering updates of the capsule label with parameters.
                        ToolbarCapsuleButton(isIncognito: isIncognito,
                                             isSelected: false, isForeground: isSelected,
                                             tabStyle: true, hueTint: hueTint,
                                             label: { _, _ in Group { } }, action: nil)
                            .overlay(isDragging ? nil : ClickCatchingView(onRightTap: { event in
                                onTap(isRightMouse: true, event: event)
                            }))
                            .onTouchDown { down in
                                if down { onTouchDown() }
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                onTap(isRightMouse: false, event: nil)
                            })
                            .accessibilityHidden(true)
                    )
                    .background(!isSingleTab || isDragging ? nil : GeometryReader { prxy in
                        Color.clear.preference(key: TabsListView.SingleTabGlobalFrameKey.self, value: prxy.safeTopLeftGlobalFrame(in: nil).rounded())
                    })
                    .background(!enableFileDrop() ? nil :
                                    Color.clear.onDrop(of: [UTType.fileURL], delegate: FileDropDelegate(onFileDrop: { [weak tab, capturedDelegate = delegate] url in
                        // capturing delegate to avoid captured self. See BE-5695
                        guard let tab = tab else { return }
                        capturedDelegate?.tabDidReceiveFileDrop(tab, url: url)
                    }))
                            .accessibilityElement()
                    )
                    .if(isDragging && applyDraggingStyle) {
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

// MARK: - Delegate forward
extension TabView {

    func onTouchDown() {
        delegate?.tabDidTouchDown(tab)
    }

    func onTap(isRightMouse: Bool, event: NSEvent?) {
        delegate?.tabDidTap(tab, isRightMouse: isRightMouse, event: event)
    }

    func onClose() {
        delegate?.tabWantsToClose(tab)
    }

    func onCopy() {
        delegate?.tabWantsToCopy(tab)
    }

    func onToggleMute(){
        delegate?.tabDidToggleMute(tab)
    }

    func onDetach() {
        delegate?.tabWantsToDetach(tab)
    }

    func enableFileDrop() -> Bool {
        delegate?.tabSupportsFileDrop(tab) == true
    }
}

private struct FileDropDelegate: DropDelegate {
    let onFileDrop: ((URL) -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        guard let onFileDrop = onFileDrop, let item = info.itemProviders(for: [UTType.fileURL]).first else {
            return false
        }
        item.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { data, error in
            do {
                let url = try (Result(data, error).get() as? Data)
                    .flatMap { String(data: $0, encoding: .utf8) }
                    .flatMap(URL.init(string:))
                url.map { url in DispatchQueue.main.async(execute: { onFileDrop(url) })  }
            } catch {
                UserAlert.showError(error: error)
            }
        }
        return true
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
        t.mediaPlayerController?.playState = .playing
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
