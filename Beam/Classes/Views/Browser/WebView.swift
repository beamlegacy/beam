//
//  WebView.swift
//  testWkWebViewSwiftUI
//
//  Created by Sebastien Metrot on 16/09/2020.
//

import SwiftUI
import Combine
import WebKit

/// A container for using a WKWebView in SwiftUI
public struct WebView: View, NSViewRepresentable {
    /// The WKWebView to display
    var webView: WKWebView

    public typealias NSViewType = NSViewContainerView<WKWebView>

    public func makeNSView(context: NSViewRepresentableContext<WebView>) -> WebView.NSViewType {
        return NSViewType()
    }

    public func updateNSView(_ nsView: WebView.NSViewType, context: NSViewRepresentableContext<WebView>) {
        
        nsView.contentView = webView
    }
}

struct WebView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello, World!")
    }
}
