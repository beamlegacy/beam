import Foundation

protocol BeamWebViewConfiguration {
    var id: UUID { get }

    /**
       Injects CSS source code into the web page.
       As this will create a `<style>` tag, the style will be implicitly executed.
       - Parameters:
         - source: The CSS source code to inject
         - when: the injection location
       */
    func addCSS(source: String, when: WKUserScriptInjectionTime)

    /**
     Injects javascript source code into the web page.
      As this will create a `<script>` tag, the code will be implicitly executed.
     - Parameters:
       - source: The JavaScript code to inject
       - when: the injection location (usually at document end so that the DOM is there)
     */
    func addJS(source: String, when: WKUserScriptInjectionTime)

    func obfuscate(str: String) -> String
}

class BeamWebViewConfigurationBase: WKWebViewConfiguration, BeamWebViewConfiguration {
    let id: UUID = UUID()

    var allowsPictureInPicture: Bool {
        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        return true
        #else
        return false
        #endif
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override init() {
        super.init()
        applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = false
        preferences.tabFocusesLinks = true
        //        preferences.plugInsEnabled = true

        preferences.isFraudulentWebsiteWarningEnabled = true
        preferences.setValue(true, forKey: "developerExtrasEnabled")
        defaultWebpagePreferences.preferredContentMode = .desktop

        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        preferences._setAllowsPicture(inPictureMediaPlayback: true)
        preferences._setFullScreenEnabled(true)
        #endif

        registerAllMessageHandlers()
    }

    func registerAllMessageHandlers() {
        LoggingMessageHandler(config: self).register(to: self)
        PasswordMessageHandler(config: self).register(to: self)
        ScorerMessageHandler(config: self).register(to: self)
        PointAndShootMessageHandler(config: self).register(to: self)
        WebNavigationMessageHandler(config: self).register(to: self)
        MediaPlayerMessageHandler(config: self).register(to: self)
        GeolocationMessageHandler(config: self).register(to: self)
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
