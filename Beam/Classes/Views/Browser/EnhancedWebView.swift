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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WebView(webView: tab.webView)
                if let pns = tab.pointAndShoot, PreferencesManager.showPNSview == true {
                    PointAndShootView(pns: pns)
                }
                if data.showTabStats, let score = tab.browsingTree.current.score {
                    TabStats(score: score)
                }
                if tab.hasError, let errorPageManager = tab.errorPageManager {
                    ErrorPageView(errorManager: errorPageManager) {
                        tab.reload()
                    }
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
        }
    }
}
