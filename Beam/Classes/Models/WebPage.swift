//
// Created by Jérôme Beau on 19/03/2021.
//

protocol WebPage {

    func addJS(source: String, when: WKUserScriptInjectionTime)

    func addCSS(source: String, when: WKUserScriptInjectionTime)

    var scrollX: CGFloat { get }

    var scrollY: CGFloat { get }

    func nativeX(x: CGFloat, origin: String) -> CGFloat

    func nativeY(y: CGFloat, origin: String) -> CGFloat

    func nativeArea(area: NSRect, origin: String) -> NSRect
}
