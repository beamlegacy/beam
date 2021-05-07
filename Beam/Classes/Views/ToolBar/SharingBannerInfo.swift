//
//  SharingBannerInfo.swift
//  Beam
//
//  Created by Remi Santos on 06/05/2021.
//

import SwiftUI

struct SharingBannerInfo: View {
    var text: String
    var icon: String?

    var body: some View {
        HStack(spacing: 0) {
            if let icon = icon {
                Icon(name: icon, color: BeamColor.Generic.text.swiftUI)
            }
            Text(text)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
        }
        .padding(.leading, BeamSpacing._60)
        .padding(.trailing, BeamSpacing._80)
        .padding(.vertical, BeamSpacing._50)
        .cornerRadius(6)
        .clipped()
        .background(
            BeamColor.Mercury.swiftUI.cornerRadius(6)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 0)
        .transition(AnyTransition.move(edge: .bottom).combined(with: AnyTransition.opacity))
    }
}
