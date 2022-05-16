//
//  SVGViewBox.swift
//  Beam
//
//  Created by Stef Kors on 12/05/2022.
//

import Foundation

/// SVG ViewBox
///
/// https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/viewBox
/// https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute
struct SVGViewBox {
    var minX: CGFloat?
    var minY: CGFloat?
    var width: CGFloat?
    var height: CGFloat = 0

    var size: NSSize {
        NSSize(width: width ?? 0, height: height)
    }
}

extension SVGViewBox {
    /// Basic implementation of ViewBox casting from string.
    /// Mostly accurate with 4 values
    init?(_ string: String) {
        guard !string.isEmpty else { return nil }
        var numbers: [CGFloat] = string
            .components(separatedBy: " ")
            .compactMap { string in
                guard let double = Double(string) else { return nil }
                return CGFloat(double)
            }

        self.height = numbers.popLast() ?? 0
        self.width = numbers.popLast()
        self.minY = numbers.popLast()
        self.minX = numbers.popLast()

    }

    init?(width: String, height: String) {
        guard let width = Double(width.removePx()),
              let height = Double(height.removePx()) else {

            return nil
        }
        self.height = height
        self.width = width
    }
}

fileprivate extension String {
    func removePx() -> String {
        self.replacingOccurrences(of: "px", with: "", options: .caseInsensitive)
    }
}
