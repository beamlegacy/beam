import Foundation
import BeamCore

class BeamWebkitUIDelegateController: WebPageHolder, WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        switch (navigationAction.navigationType) {
        case .other:
            Logger.shared.logInfo("""
                                  Redirecting toward a new window x=\(windowFeatures.x), y=\(windowFeatures.y),
                                  width=\(windowFeatures.width), height=\(windowFeatures.height), 
                                  \(windowFeatures.allowsResizing != nil ? "resizable" : "not resizable")
                                  containing \(navigationAction.request.url?.absoluteString)
                                  """, category: .web)
            return page.createNewWindow(url, configuration, windowFeatures: windowFeatures, setCurrent: true)
        default:
            Logger.shared.logInfo("Creating new webview tab for \(navigationAction.request.url?.absoluteString)", category: .web)
            let newTab = page.createNewTab(url, configuration, setCurrent: true)
            return newTab.webView
        }
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Logger.shared.logDebug("webView runJavaScriptAlertPanelWithMessage \(message)", category: .web)

        // Set the message as the NSAlert text
        let alert = NSAlert()
        alert.informativeText = message
        alert.addButton(withTitle: "Ok")

        // Display the NSAlert
        alert.runModal()

        // Call completionHandler
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptConfirmPanelWithMessage \(message)", category: .web)

        // Set the message as the NSAlert text
        let alert = NSAlert()
        alert.informativeText = message

        // Add a confirmation button “OK”
        // and cancel button “Cancel”
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        // Display the NSAlert
        let action = alert.runModal()

        // Call completionHandler with true only
        // if the user selected OK (the first button)
        completionHandler(action == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        Logger.shared.logDebug("webView runJavaScriptTextInputPanelWithPrompt \(prompt) default: \(defaultText ?? "")",
                               category: .web)

        // Set the prompt as the NSAlert text
        let alert = NSAlert()
        alert.informativeText = prompt
        alert.addButton(withTitle: "Submit")

        // Add an input NSTextField for the prompt
        let inputFrame = NSRect(
            x: 0,
            y: 0,
            width: 300,
            height: 24
        )

        let textField = NSTextField(frame: inputFrame)
        textField.placeholderString = ("Your input")
        alert.accessoryView = textField

        // Display the NSAlert
        alert.runModal()

        // Call completionHandler with
        // the user input from textField
        completionHandler(textField.stringValue)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        Logger.shared.logDebug("webView runOpenPanel", category: .web)
        completionHandler(nil)
    }
}
