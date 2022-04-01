import Foundation

protocol BeamWebViewConfiguration {
    var id: UUID { get }
    var handlers: [SimpleBeamMessageHandler] { get }

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

    func registerAllMessageHandlers()

    func obfuscate(str: String) -> String
}

let BeamWebViewConfigurationBaseid: UUID = UUID()
class BeamWebViewConfigurationBase: WKWebViewConfiguration, BeamWebViewConfiguration {
    let id: UUID = BeamWebViewConfigurationBaseid

    var handlers: [SimpleBeamMessageHandler] = []

    static var allowsPictureInPicture: Bool {
        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        return true
        #else
        return false
        #endif
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    /// Doing `registerAllMessageHandlers` in the convenience init fixes a bug in webkit
    /// where the `WKWebViewConfiguration` creates multiple references to the assigned WKMessageHandlers
    convenience init(handlers: [SimpleBeamMessageHandler] = []) {
        self.init()
        self.handlers = handlers
        registerAllMessageHandlers()

        if let windowCleanupSource = loadFile(from: "WindowCleanup", fileType: "js") {
            addJS(source: windowCleanupSource, when: .atDocumentEnd)
        }
    }

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
        preferences._setBackspaceKeyNavigationEnabled(false)
        #endif
    }

    func registerAllMessageHandlers() {
        for handler in handlers {
            for messageName in handler.messages {
                userContentController.add(handler, name: messageName)
            }

            if let cssFileName = handler.cssFileName,
               let cssCode = loadFile(from: cssFileName, fileType: "css") {
                addCSS(source: cssCode, when: .atDocumentEnd)
            }

            if let jsCode = loadFile(from: handler.jsFileName, fileType: "js") {
                addJS(source: jsCode, when: handler.jsCodePosition, forMainFrameOnly: handler.forMainFrameOnly)
            }
        }
    }

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
        // hide code behind random ID
        let uuidIdentifier = id.uuidString.replacingOccurrences(of: "-", with: "_")
        let stringWithIdsReplaced = str.replacingOccurrences(of: "__ID__", with: "beam" + uuidIdentifier)

        // embed the embed regex pattern
        let pattern = SupportedEmbedDomains.shared.javaScriptPattern
        return stringWithIdsReplaced.replacingOccurrences(of: "__EMBEDPATTERN__", with: pattern)
    }

}
