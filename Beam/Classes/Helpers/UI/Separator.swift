//
//  Separator.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import SwiftUI

struct Separator: View {
    static let defaultHeight: CGFloat = 1.0
    var body: some View {
        Rectangle()
            .fill(Color(.verticalSeparatorColor))
            .frame(height: Self.defaultHeight)
    }
}

struct Separator_Previews: PreviewProvider {
    static var previews: some View {
        Separator()
    }
}
