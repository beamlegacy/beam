//
//  ContentView.swift
//  Shared
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI

struct AutoCompleteView: View {
    @Binding var autoComplete: [AutoCompleteResult]
    var body: some View {
        if autoComplete.count != 0 {
            return AnyView(
                AutoCompleteList(selectedIndex: .constant(0), elements: $autoComplete)
            .padding([.leading, .trailing], CGFloat(150))
            .padding([.top], CGFloat(50))
            )
        }
        return AnyView(Text("Search for something or create a card"))
    }
}

struct ModeView: View {
    @EnvironmentObject var state: BeamState
    @State var t: String = "xzcsdf"
    var body: some View {
        switch state.mode {
        case .web:
            return AnyView(WebView(webView: state.webViewStore.webView))
        case .note:
            return AnyView(ScrollView([.vertical]) {
                AutoCompleteView(autoComplete: $state.completedQueries)
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
        ModeView().background(Color(.white))
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            ContentView(webViewStore: .constant(WebViewStore()), mode: .web)
//        }
//    }
//}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
