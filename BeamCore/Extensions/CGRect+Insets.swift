//
//  CGRect+Insets.swift
//  BeamCore
//
//  Created by Frank Lefebvre on 05/05/2022.
//

import Foundation

public struct BeamEdgeInsets: Codable {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    public static let zero = BeamEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

public extension CGRect {
    func inset(by edgeInsets: BeamEdgeInsets) -> CGRect {
        var rect = offsetBy(dx: edgeInsets.left, dy: edgeInsets.top)
        rect.size.width -= edgeInsets.left + edgeInsets.right
        rect.size.height -= edgeInsets.top + edgeInsets.bottom
        return rect
    }
}
