import Foundation
import BeamCore

class BeamWebkitUIDelegateController: NSObject, WebPageRelated, WKUIDelegate {
    weak var page: WebPage?

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Assigning it to an optional to check if we have a value
        // see: https://linear.app/beamapp/issue/BE-4279/exc-breakpoint-exception-6-code-2765529536-subcode-8
        let optionalRequest: URLRequest? = navigationAction.request
        guard let request = optionalRequest else {
            Logger.shared.logError("Expected createWebViewWith to have a NavigationAction with URLRequest", category: .web)
            return nil
        }

        if navigationAction.navigationType == .other {
            let defaultValue = true
            let menubar = windowFeatures.menuBarVisibility?.boolValue ?? defaultValue
            let statusBar = windowFeatures.statusBarVisibility?.boolValue ?? defaultValue
            let toolBars = windowFeatures.toolbarsVisibility?.boolValue ?? defaultValue
            let isNewWindow = !toolBars
            if isNewWindow, let page = page {
                let numberOrNil: (NSNumber?) -> String = { $0?.stringValue ?? "nil" }
                Logger.shared.logInfo("""
                                      Redirecting toward a new window x=\(numberOrNil(windowFeatures.x)), y=\(numberOrNil(windowFeatures.y)),
                                      width=\(numberOrNil(windowFeatures.width)), height=\(numberOrNil(windowFeatures.height)),
                                      \(windowFeatures.allowsResizing != nil ? "resizable" : "not resizable"),
                                      menuBar=\(menubar),
                                      statusBar=\(statusBar),
                                      toolBars=\(toolBars),
                                      containing \(String(describing: request.url?.absoluteString))
                                      """, category: .web)
                return page.createNewWindow(request, configuration, windowFeatures: windowFeatures, setCurrent: true)
            } else {
                Logger.shared.logInfo("Redirecting toward new tab containing \(request)", category: .web)
            }
        }
        Logger.shared.logInfo("Creating new webview tab for \(request)", category: .web)
        let newTab = self.page?.createNewTab(request, configuration, setCurrent: true, rect: windowFeatures.toRect())
        guard let newWebView = newTab?.webView else {
            fatalError("should have webview")
        }
        return newWebView
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

    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
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

    /// We allow all media capture devices. This enables screen sharing capability.
    /// But this requires us to manually tell WebKit to present the permission prompt in `requestMediaCapturePermissionFor`. Otherwise everything is allowed without the user knowing.
    /// Ideally we could slide in there and have our own policy and preferences.
    ///
    /// New apis and private apis are coming to better support screen capture (with window/entire screen maybe?)
    /// https://github.com/WebKit/WebKit/commit/09fc9d6843256df9d7a50dd6700d8f0932db2bb2
    func _webView(_ webView: WKWebView, requestUserMediaAuthorizationFor devices: _WKCaptureDevices, url: URL, mainFrameURL: URL, decisionHandler: @escaping ((Bool) -> Void)) {

        if #available(macOS 12.0, *), !devices.contains(.display) {
            // `requestMediaCapturePermissionFor` will tell WebKit to show the default prompts. e
            decisionHandler(true)
        } else {
            showPermissionPrompt(for: url, devices: devices) { answer in
                decisionHandler(answer)
            }
        }
    }

    private func showPermissionPrompt(for url: URL, devices: _WKCaptureDevices, decisionHandler: @escaping ((Bool) -> Void)) {

        let requestScreen = devices.contains(.display)
        let requestCamera = devices.contains(.camera)
        let requestMicrophone = devices.contains(.microphone)

        var devicesMessage = ""
        if requestScreen {
            devicesMessage += "observe your screen"
            if requestCamera || requestMicrophone {
                devicesMessage += "and"
            }
        }

        if requestCamera {
            devicesMessage += "use your camera"
        }
        if requestMicrophone {
            if requestCamera {
                devicesMessage += " and microphone"
            } else {
                devicesMessage += "use your microphone"
            }
        }
        let title = "Allow \"\(url.minimizedHost ?? url.urlStringWithoutScheme)\" to \(devicesMessage)"
        UserAlert.showAlert(message: title, buttonTitle: "Allow", secondaryButtonTitle: "Don't Allow", buttonAction: {
            decisionHandler(true)
        }, secondaryButtonAction: {
            decisionHandler(false)
        })
    }

}
#endif
