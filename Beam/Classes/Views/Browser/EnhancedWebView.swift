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
                        .opacity(0.5)
                }

                if windowInfo.windowIsMain || tabBelongsToThisWindow {
                    switch tab.contentDescription {
                    case let pdfContentDescription as PDFContentDescription:
                        PDFContentView(
                            contentState: pdfContentDescription.contentState,
                            onClickLink: { url in
                                tab.load(url: url)
                            }
                        ).padding(.top, topContentInset)

                    default:
                        WebView(webView: tab.webView, topContentInset: topContentInset)
                            .webViewStatusBar(isVisible: tab.showsStatusBar) {
                                WebViewStatusText(mouseHoveringLocation: tab.mouseHoveringLocation)
                            }
                            .if(!tab.webView.supportsTopContentInset) { $0.padding(.top, topContentInset) }
                    }

                    ZStack {
                        if let pns = tab.pointAndShoot, PreferencesManager.showPNSView == true {
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

                                if let search = tab.searchViewModel {
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
                        if let search = tab.searchViewModel {
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
                        tab.reload()
                    }
                }
            }
        }
    }
}
