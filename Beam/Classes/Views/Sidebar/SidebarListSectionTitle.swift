//
//  SidebarListSectionTitle.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 18/05/2022.
//

import SwiftUI

struct SidebarListSectionTitle: View {

    var title: String
    var iconName: String

    var body: some View {
        HStack(spacing: 6.0) {
            if let iconName = iconName {
                Icon(name: iconName, width: 12, color: foregroundColor)
            }
            Text(title)
            Spacer()
        }
        .font(BeamFont.medium(size: 11).swiftUI)
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 8)
        .frame(width: 220, height: 30)
    }

    private var foregroundColor: Color {
        BeamColor.LightStoneGray.swiftUI
    }
}

struct SidebarListSectionTitle_Previews: PreviewProvider {
    static var previews: some View {
        SidebarListSectionTitle(title: "Recent", iconName: "editor-recent")
    }
}
