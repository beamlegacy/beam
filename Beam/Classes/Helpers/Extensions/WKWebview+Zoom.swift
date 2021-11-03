//
//  WKWebview+Zoom.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import Foundation

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
