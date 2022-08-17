//
//  OmniboxCustomStatusView.swift
//  Beam
//
//  Created by Remi Santos on 10/08/2022.
//

import SwiftUI

/// A simple status view to be used with omnibox mode .customView()
///
/// This is for now very tied to the note/tabGroup sharing UI. But feel free to make it more generic.
struct OmniboxCustomStatusView: View {

    /// Helper to wrap in an anyview so that clients don't have to import SwiftUI.
    var asAnyView: AnyView {
        AnyView(self)
    }

    var title: String = ""
    var suffix: String = ""
    var suffixColor: Color
    var icon: String = "collect-generic"

    var body: some View {
        HStack(spacing: BeamSpacing._120) {
            Icon(name: icon, color: BeamColor.Generic.text.swiftUI)
            Text(title)
                .font(BeamFont.regular(size: 17).swiftUI)
            +
            Text(suffix)
                .font(BeamFont.medium(size: 17).swiftUI)
                .foregroundColor(suffixColor)

            Spacer()
            HStack(spacing: BeamSpacing._20) {
                Icon(name: "editor-url_link", color: BeamColor.LightStoneGray.swiftUI)
                Text("Link Copied")
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
        }
        .foregroundColor(BeamColor.Generic.text.swiftUI)
    }
}
