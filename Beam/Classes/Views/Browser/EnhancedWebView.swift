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
        ZStack {
            WebView(webView: tab.webView)
            if let pns = tab.pointAndShoot {
                PointAndShootView(pns: pns)
            }
            if data.showTabStats, let score = tab.browsingTree.current.score {
                TabStats(score: score)
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
        }
    }
}
