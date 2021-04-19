//
// Created by Jérôme Beau on 19/03/2021.
//

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

    var scrollX: CGFloat { get }

    var scrollY: CGFloat { get }

    var webPositions: WebPositions { get }
}
