//
//  WKWebview+Zoom.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import Foundation

// MARK: - Zoom
extension WKWebView {
    func zoomReset() {
        pageZoom = 1
    }

    func zoomIn() {
        pageZoom += 0.1
    }

    func zoomOut() {
        pageZoom -= 0.1
    }

    func zoomLevel() -> CGFloat {
        pageZoom
    }
}

// MARK: - Navigation
extension WKWebView {

    /// Use JS to redirect the page without adding a history entry
    func replaceLocation(with url: URL) {
        let safeUrl = url.absoluteString.replacingOccurrences(of: "'", with: "%27")
        evaluateJavaScript("location.replace('\(safeUrl)')")
    }

}

// MARK: - Top Content inset support
// (for transparent toolbar)
extension WKWebView {

    var supportsTopContentInset: Bool {
#if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        true
#else
        false
#endif
    }

    var topContentInset: CGFloat {
        guard supportsTopContentInset else { return 0 }
        var value: CGFloat = 0
#if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        value = self._topContentInset()
#endif
        return value
    }

    func setTopContentInset(_ topContentInset: CGFloat) {
        guard supportsTopContentInset else { return }
#if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        self._setAutomaticallyAdjustsContentInsets(false)
        self._setTopContentInset(topContentInset)
#endif
    }

}
