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

    private let topContentInset: CGFloat = OmniboxV2Toolbar.height

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                let tabBelongsToThisWindow = tab.state === state
                if tab.isPinned && !state.windowIsMain && !tabBelongsToThisWindow, let captured = tab.screenshotCapture {
                    Image(nsImage: captured).scaledToFit()
                        .opacity(0.5)
                }
                if state.windowIsMain || tabBelongsToThisWindow {
                    WebView(webView: tab.webView, topContentInset: topContentInset)
                        .if(!tab.webView.supportsTopContentInset) { $0.padding(.top, topContentInset) }
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
                        if let search = tab.searchViewModel {
                            VStack {
                                HStack(alignment: .top, spacing: 12) {
                                    Spacer()
                                    SearchInContentView(viewModel: search)
                                        .padding(.top, 10)
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
