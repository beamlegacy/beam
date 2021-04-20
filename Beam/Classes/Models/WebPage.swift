import BeamCore

/**
 The expected API for a WebPage to work (received messages, point and shoot) with.

 Defining this protocol allows to provide a mock implementation for testing.
 */
protocol WebPage {
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

    func executeJS(objectName: String, jsCode: String)

    var scrollX: CGFloat { get set }

    var scrollY: CGFloat { get set }

    var originalQuery: String? { get }

    var pointAndShootAllowed: Bool { get }

    var title: String { get }

    var url: URL? { get }

    /**
 Add current page to a Note.

 - Parameter allowSearchResult:
 - Returns:
 */
    func addToNote(allowSearchResult: Bool) -> BeamElement?

    func setDestinationNote(_ note: BeamNote, rootElement: BeamElement?)

    func getNote(fromTitle: String) -> BeamNote?
}
