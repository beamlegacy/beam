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
       - forMainFrameOnly: If scripts should be added to the main window frame or all frames
     */
    func addJS(source: String, when: WKUserScriptInjectionTime, forMainFrameOnly: Bool)

    func obfuscate(str: String) -> String
}

let BeamWebViewConfigurationBaseid: UUID = UUID()
class BeamWebViewConfigurationBase: WKWebViewConfiguration, BeamWebViewConfiguration {
    let id: UUID = BeamWebViewConfigurationBaseid

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

        preferences.javaScriptCanOpenWindowsAutomatically = false
        preferences.tabFocusesLinks = true
        //        preferences.plugInsEnabled = true

        preferences.isFraudulentWebsiteWarningEnabled = true
        preferences.setValue(true, forKey: "developerExtrasEnabled")
        defaultWebpagePreferences.preferredContentMode = .desktop
        defaultWebpagePreferences.allowsContentJavaScript = true
        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        preferences._setAllowsPicture(inPictureMediaPlayback: true)
        preferences._setFullScreenEnabled(true)
        #endif

        registerAllMessageHandlers()
    }

    func registerAllMessageHandlers() {}

    func addJS(source: String, when: WKUserScriptInjectionTime, forMainFrameOnly: Bool = false) {
        let parameterized = source.replacingOccurrences(of: "__ENABLED__", with: "true")
        let obfuscated = obfuscate(str: parameterized)
        let script = WKUserScript(source: obfuscated, injectionTime: when, forMainFrameOnly: forMainFrameOnly)
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
