//
//  MainToolBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import AppKit

struct MainToolBar: View {
    @EnvironmentObject var state: BeamState
    var body: some View {
        SearchBar(searchText: $state.searchQuery, selectionIndex: $state.selectionIndex,
                  canGoBack: state.webViewStore.webView.canGoBack,
                  canGoForward: state.webViewStore.webView.canGoForward,
                  goBack: { state.webViewStore.webView.goBack() },
                  goForward: { state.webViewStore.webView.goForward() })
    }
}

