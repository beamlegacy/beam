//
//  ErrorPageView.swift
//  Beam
//
//  Created by Florian Mari on 16/09/2021.
//

import SwiftUI

struct ErrorPageView: View {
    let errorManager: ErrorPageManager
    let onReloadTab: () -> Void?
    
    var errorImage: some View {
        Image(errorManager.error == .radblock ? "error-page_adblock" : "error-page")
            .renderingMode(.template)
            .foregroundColor(BeamColor.AlphaGray.swiftUI)
            .padding(.bottom, 16)
    }

    struct ActionButton: View {
        var title: String
        var action: (() -> Void)
        @State private var isHovering: Bool = false

        var body: some View {
            Button {
                 action()
             } label: {
                 Text(title)
                     .font(BeamFont.regular(size: 13).swiftUI)
             }
             .buttonStyle(.plain)
             .padding(.vertical, 7)
             .padding(.horizontal, 30)
             .foregroundColor( isHovering ? BeamColor.Bluetiful.swiftUI : BeamColor.Corduroy.swiftUI)
             .background(BeamColor.Mercury.swiftUI)
             .onHover { isHovering = $0 }
             .cornerRadius(3)
        }
    }

    var body: some View {
        VStack {
            Spacer()
            errorImage
            Text(errorManager.title)
                .font(BeamFont.medium(size: 17).swiftUI)
                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                .padding(.bottom, 10)
            Text(errorManager.primaryMessage)
                .lineLimit(nil)
                .frame(maxWidth: 298)
                .font(BeamFont.medium(size: 12).swiftUI)
                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                .padding(.bottom, 10)
            Text(errorManager.secondaryMessage)
                .font(BeamFont.medium(size: 12).swiftUI)
                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            if errorManager.error == .radblock {
                Separator(horizontal: true, hairline: true)
                    .frame(maxWidth: 298)
                    .padding(.vertical, 20)
                Text("Disable blocking for \(errorManager.domain)")
                    .font(BeamFont.medium(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Niobium.swiftUI)
                    .padding(.bottom, 14)
                HStack(spacing: 12) {
                    ActionButton(title: "Just this time") {
                        errorManager.authorizeJustOnce {
                            onReloadTab()
                        }
                    }
                    ActionButton(title: "Permanently") {
                        errorManager.permanentlyAuthorize {
                            onReloadTab()
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(BeamColor.Nero.swiftUI)
        .animation(nil)
    }
}
