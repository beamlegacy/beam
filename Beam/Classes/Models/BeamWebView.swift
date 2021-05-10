import Foundation

class BeamWebView: WKWebView {
//    override var safeAreaInsets: NSEdgeInsets {
//        return NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    }
    weak var page: BrowserTab?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        allowsBackForwardNavigationGestures = true
        allowsLinkPreview = true
        allowsMagnification = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Catching those event to avoid funk sound
    override func keyDown(with event: NSEvent) {
        if let key = event.specialKey {
            if key == .leftArrow || key == .rightArrow {
                return
            }
        }
        super.keyDown(with: event)
    }
}
