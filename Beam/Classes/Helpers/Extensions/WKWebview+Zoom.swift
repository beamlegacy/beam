//
//  WKWebview+Zoom.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import Foundation

extension WKWebView {

    private func setZoomWithJS(_ zoomLevel: Float) {
        evaluateJavaScript("document.body.style.zoom = \(zoomLevel)", completionHandler: nil)
    }

    private func getCurrentZoomFromJS(_ completionHandler: @escaping (Float) -> Void) {
        evaluateJavaScript("document.body.style.zoom") { result, _ in
            guard let zoom = result as? String, !zoom.isEmpty else {
                completionHandler(1)
                return
            }
            completionHandler((zoom as NSString).floatValue)
        }
    }

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
