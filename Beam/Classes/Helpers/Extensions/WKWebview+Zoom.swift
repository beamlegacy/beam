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
        if #available(macOS 11.0, *) {
            pageZoom = 1
        } else {
            setZoomWithJS(1.0)
        }
    }

    func zoomIn() {
        if #available(macOS 11.0, *) {
            pageZoom += 0.1
        } else {
            getCurrentZoomFromJS { zoom in
                self.setZoomWithJS(zoom + 0.1)
            }
        }
    }

    func zoomOut() {
        if #available(macOS 11.0, *) {
            pageZoom -= 0.1
        } else {
            getCurrentZoomFromJS { zoom in
                self.setZoomWithJS(zoom - 0.1)
            }
        }
    }

    func zoomLevel() -> CGFloat {
        if #available(macOS 11.0, *) {
            return pageZoom
        }
        // For PNS scaling, document zoom fallback isn't handled here, but retrieved in JS directly
        return 1.0
    }
}
