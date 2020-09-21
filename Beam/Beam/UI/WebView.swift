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
    public let webView: WKWebView
    
    public typealias NSViewType = NSViewContainerView<WKWebView>
    
    public init(webView: WKWebView) {
        self.webView = webView
        self.webView.configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        self.webView.configuration.preferences.javaScriptEnabled = true
    }
    
    public func makeNSView(context: NSViewRepresentableContext<WebView>) -> WebView.NSViewType {
        return NSViewContainerView()
    }
    
    public func updateNSView(_ nsView: WebView.NSViewType, context: NSViewRepresentableContext<WebView>) {
        // If its the same content view we don't need to update.
        if nsView.contentView !== webView {
            nsView.contentView = webView
        }
    }
}

struct WebView_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
