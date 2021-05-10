import Foundation

class BrowserTabConfiguration: WKWebViewConfiguration, BeamWebViewConfiguration {
    let id: UUID = UUID()

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override init() {
        super.init()
        applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = false
        preferences.tabFocusesLinks = true
//        preferences.plugInsEnabled = true
        preferences._setFullScreenEnabled(true)
        preferences.isFraudulentWebsiteWarningEnabled = true
        defaultWebpagePreferences.preferredContentMode = .desktop

        let loggingMessageHandler = LoggingMessageHandler(page: self)
        loggingMessageHandler.register(to: self)

        let passwordMessageHandler = PasswordMessageHandler(page: self)
        passwordMessageHandler.register(to: self)

        let scorerMessageHandler = ScorerMessageHandler(page: self)
        scorerMessageHandler.register(to: self)

        let pointAndShootMessageHandler = PointAndShootMessageHandler(config: self)
        pointAndShootMessageHandler.register(to: self)
    }

    func addJS(source: String, when: WKUserScriptInjectionTime) {
        let parameterized = source.replacingOccurrences(of: "__ENABLED__", with: "true")
        let obfuscated = obfuscate(str: parameterized)
        let script = WKUserScript(source: obfuscated, injectionTime: when, forMainFrameOnly: false)
        userContentController.addUserScript(script)
    }

    func addCSS(source: String, when: WKUserScriptInjectionTime) {
        let styleSrc = """
                       var style = document.createElement('style');
                       style.innerHTML = `\(source)`;
                       document.head.appendChild(style);
                       """
        addJS(source: styleSrc, when: when)
    }

    func obfuscate(str: String) -> String {
        let uuidIdentifier = id.uuidString.replacingOccurrences(of: "-", with: "_")
        return str.replacingOccurrences(of: "__ID__", with: "beam" + uuidIdentifier)
    }
}
