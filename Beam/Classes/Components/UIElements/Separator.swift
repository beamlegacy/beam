//
//  Separator.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI

struct Separator: View {
    var horizontal: Bool = false

    static let height: CGFloat = 1.0
    static let width: CGFloat = 1.0
    var body: some View {
        Rectangle()
            .fill(Color(.beamSeparatorColor))
            .frame(width: !horizontal ? Self.width : nil, height: horizontal ? Self.height : nil)
    }
}

struct Separator_Previews: PreviewProvider {
    static var previews: some View {
        Separator()
    }
}
