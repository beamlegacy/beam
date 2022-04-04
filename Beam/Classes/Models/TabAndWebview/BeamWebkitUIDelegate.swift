import Foundation
import BeamCore

class BeamWebkitUIDelegateController: NSObject, WebPageRelated, WKUIDelegate {
    weak var page: WebPage?

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if navigationAction.navigationType == .other {
            let defaultValue = true
            let menubar = windowFeatures.menuBarVisibility?.boolValue ?? defaultValue
            let statusBar = windowFeatures.statusBarVisibility?.boolValue ?? defaultValue
            let toolBars = windowFeatures.toolbarsVisibility?.boolValue ?? defaultValue
            let isNewWindow = !toolBars
            if isNewWindow {
                let numberOrNil: (NSNumber?) -> String = { $0?.stringValue ?? "nil" }
                Logger.shared.logInfo("""
                                      Redirecting toward a new window x=\(numberOrNil(windowFeatures.x)), y=\(numberOrNil(windowFeatures.y)),
                                      width=\(numberOrNil(windowFeatures.width)), height=\(numberOrNil(windowFeatures.height)),
                                      \(windowFeatures.allowsResizing != nil ? "resizable" : "not resizable"),
                                      menuBar=\(menubar),
                                      statusBar=\(statusBar),
                                      toolBars=\(toolBars),
                                      containing \(url.absoluteString)
                                      """, category: .web)
                return self.page?.createNewWindow(url, configuration, windowFeatures: windowFeatures, setCurrent: true)
            } else {
                Logger.shared.logInfo("Redirecting toward new tab containing \(url.absoluteString)", category: .web)
            }
        }
        Logger.shared.logInfo("Creating new webview tab for \(url.absoluteString)", category: .web)
        let newTab = self.page?.createNewTab(url, configuration, setCurrent: true)
        return newTab?.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        Logger.shared.logDebug("webView webDidClose", category: .web)
        _ = (self.page as? BrowserTab)?.state?.closeCurrentTab()
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        Logger.shared.logDebug("webView runJavaScriptAlertPanelWithMessage \(message)", category: .web)

        // Set the message as the NSAlert text
        let alert = NSAlert()
        alert.informativeText = message
        alert.addButton(withTitle: "OK")

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

        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        openPanel.canChooseFiles = true
        let response = openPanel.runModal()
        let choice = response == .OK ? openPanel.urls : nil
        completionHandler(choice)
    }
}

#if BEAM_WEBKIT_ENHANCEMENT_ENABLED
extension BeamWebkitUIDelegateController: WKUIDelegatePrivate {

    /// Sets the window frame size so `window.outerWidth` returns the frame width instead of `0`
    /// Fixes sites like google sheets.
    /// - Parameters:
    ///   - webView:
    ///   - completionHandler: 
    func _webView(_ webView: WKWebView, getWindowFrameWithCompletionHandler completionHandler: @escaping (NSRect) -> Void) {
        let frame = self.page?.webView.frame ?? .zero
        completionHandler(frame)
    }

    func _webView(_ webView: WKWebView!, requestUserMediaAuthorizationFor devices: _WKCaptureDevices, url: URL!, mainFrameURL: URL!, decisionHandler: ((Bool) -> Void)!) {
        decisionHandler(true)
    }

}
#endif
