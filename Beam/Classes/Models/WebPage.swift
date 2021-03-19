//
// Created by Jérôme Beau on 19/03/2021.
//

protocol WebPage {

    func addJS(source: String, when: WKUserScriptInjectionTime)

    func addCSS(source: String, when: WKUserScriptInjectionTime)
}
