//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct AutoCompleteView: View {
    @EnvironmentObject var state: BeamState
    var body: some View {
        if state.autoComplete.count != 0 {
            let elements = state.autoComplete
            return AnyView(List {
                ForEach(0..<elements.count) { index in
                    Text(elements[index])
                }
            })
        }
        return AnyView(Text("Search for something or create a card"))
    }
}

struct ModeView: View {
    @EnvironmentObject var state: BeamState
    var body: some View {
        switch state.mode {
        case .web:
            return AnyView(WebView(webView: state.webViewStore.webView))
        case .note:
            return AnyView(ScrollView([.vertical]) {
                AutoCompleteView()
                    .frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 480, idealHeight: 600, maxHeight: .infinity, alignment: .center)
                
            })
            
        case .history:
            return AnyView(ScrollView([.vertical]) {
                Text("Bleh\nSome History\nFoo\nBar").frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 480, idealHeight: 600, maxHeight: .infinity, alignment: .center)
            })
        }
    }
}

struct ContentView: View {
    var body: some View {
        ModeView()
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            ContentView(webViewStore: .constant(WebViewStore()), mode: .web)
//        }
//    }
//}
