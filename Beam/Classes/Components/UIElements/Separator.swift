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

    static let height: CGFloat = 1.0
    static let width: CGFloat = 1.0

    static private let hairlineHeight: CGFloat = 0.5
    static private let hairlineWidth: CGFloat = 0.5

    private var width: CGFloat? {
        guard !horizontal else { return nil }
        return hairline ? Self.hairlineWidth : Self.width
    }
    private var height: CGFloat? {
        guard horizontal else { return nil }
        return hairline ? Self.hairlineHeight : Self.height
    }

    var body: some View {
        Rectangle()
            .fill(BeamColor.Generic.separator.swiftUI)
            .frame(width: width, height: height)
    }
}

struct Separator_Previews: PreviewProvider {
    static var previews: some View {
        Separator()
    }
}
