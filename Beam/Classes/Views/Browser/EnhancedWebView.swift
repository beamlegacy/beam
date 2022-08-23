//
//  EnhancedWebView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/07/2021.
//

import SwiftUI

struct EnhancedWebView: View {

    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var data: BeamData
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    private let topContentInset: CGFloat = Toolbar.height

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                let tabBelongsToThisWindow = tab.state === state
                if tab.isPinned && !windowInfo.windowIsMain && !tabBelongsToThisWindow, let captured = tab.screenshotCapture {
                    Image(nsImage: captured).scaledToFit()
                        .padding(.top, topContentInset)
                        .opacity(0.5)
                }

                if windowInfo.windowIsMain || tabBelongsToThisWindow {
                    switch tab.contentDescription {
                    case let pdfContentDescription as PDFContentDescription:
                        PDFContentView(
                            contentState: pdfContentDescription.contentState,
                            searchState: tab.searchViewModel,
                            onClickLink: { url in
                                tab.load(request: URLRequest(url: url))
                            }
                        ).padding(.top, topContentInset)

                    default:
                        WebViewContainer(contentView: tab.contentView, topContentInset: topContentInset)
                            .webViewStatusBar(isVisible: tab.showsStatusBar) {
                                WebViewStatusText(mouseHoveringLocation: tab.mouseHoveringLocation)
                            }
                            .if(!tab.webView.supportsTopContentInset) { $0.padding(.top, topContentInset) }
                    }

                    ZStack {
                        if let pns = tab.pointAndShoot, PreferencesManager.showPNSView {
                            PointAndShootView(pns: pns)
                        }
                        if let viewModel = tab.authenticationViewModel {
                            ZStack {
                                BeamColor.AlphaGray.swiftUI.opacity(0.5)
                                VStack {
                                    AuthenticationView(viewModel: viewModel)
                                        .padding()
                                    Spacer()
                                }
                            }
                        }

                        // Floating top-right toolbars
                        VStack(alignment: .trailing) {
                            HStack(alignment: .top) {
                                Spacer()

                                if let search = tab.searchViewModel, search.showPanel {
                                    SearchInContentView(viewModel: search)
                                        .padding(.trailing, 30)
                                }

                                if let pdfContentDescription = tab.contentDescription as? PDFContentDescription,
                                   pdfContentDescription.contentState.isLoaded {
                                    PDFToolbar(contentState: pdfContentDescription.contentState)
                                        .padding(.trailing, 20)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 10)

                        // Search locations
                        if let search = tab.searchViewModel, search.showPanel {
                            VStack(alignment: .trailing) {
                                HStack(alignment: .top) {
                                    Spacer()
                                    SearchLocationView(viewModel: search, height: proxy.size.height)
                                        .frame(width: 8)
                                        .padding(.trailing, 10)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, topContentInset)
                }

                if data.showTabStats, let score = tab.browsingTree.current.score {
                    TabStats(score: score)
                }

                if tab.hasError, let errorPageManager = tab.errorPageManager {
                    ErrorPageView(errorManager: errorPageManager) {
                        tab.reload(configureWebViewWithAdBlocker: false)
                    }
                }
            }
        }
    }
}

/// Container specialized for webviews.
/// The content view needs to be wrapped in another container to avoid glitching issues and frame resets due to the creation
/// of the `NSViewRepresentable` conforming struct.
///
/// Fixes https://linear.app/beamapp/issue/BE-4286/video-in-full-screen-switch-tab-doesnt-display-tab-and-dismiss-full
struct WebViewContainer: View, NSViewRepresentable {
    typealias ContentView = NSViewContainerView<BeamWebView>
    typealias NSViewType = NSViewContainerView<ContentView>

    let contentView: NSViewContainerView<BeamWebView>
    let topContentInset: CGFloat

    func makeNSView(context: Context) -> NSViewType {
        return NSViewType()
    }

    func updateNSView(_ nsView: NSViewContainerView<ContentView>, context: Context) {
        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        if let webView = contentView.contentView, webView.supportsTopContentInset, !webView._isInFullscreen {
            webView.setTopContentInset(topContentInset)
        }
        #endif
        nsView.contentView = contentView
    }
}
