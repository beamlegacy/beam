import Foundation

class BeamWebView: WKWebView {

    weak var page: BrowserTab?
    private let automaticallyResignResponder = true

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        allowsBackForwardNavigationGestures = true
        allowsLinkPreview = true
        allowsMagnification = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidMoveToSuperview() {
        if automaticallyResignResponder && superview == nil && self.window?.firstResponder == self {
            self.window?.makeFirstResponder(nil)
        }
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = BeamColor.Generic.background.cgColor
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
