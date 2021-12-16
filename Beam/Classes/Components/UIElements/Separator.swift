//
//  Separator.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI

struct Separator: View {
    var horizontal: Bool = false
    var hairline: Bool = false
    var rounded: Bool = false
    var color: BeamColor = BeamColor.Generic.separator

    static let height: CGFloat = 1.0
    static let width: CGFloat = 1.0

    static let hairlineHeight: CGFloat = 0.5
    static let hairlineWidth: CGFloat = 0.5

    private var width: CGFloat? {
        guard !horizontal else { return nil }
        return hairline ? Self.hairlineWidth : Self.width
    }
    private var height: CGFloat? {
        guard horizontal else { return nil }
        return hairline ? Self.hairlineHeight : Self.height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: rounded ? 1 : 0)
            .fill(color.swiftUI)
            .frame(width: width, height: height)
    }
}

struct Separator_Previews: PreviewProvider {
    static var previews: some View {
        Separator()
    }
}
