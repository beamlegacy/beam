//
//  OnboardingImportsView.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import SwiftUI

struct OnboardingImportsView: View {
    @State private var selectedBrowser: String = "Safari"
    @State private var checkHistory = true
    @State private var checkPassword = true

    // Work In Progress. Focusing on other Onboarding steps first.
    var body: some View {
        VStack(spacing: 0) {
            OnboardingView.TitleText(title: "Import your data")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: BeamSpacing._40) {
                    Icon(name: "field-web")
                    Text(selectedBrowser)
                }
                .padding(.vertical, 3)
                Separator(horizontal: true)
                    .padding(.bottom, 16)
                VStack(alignment: .leading, spacing: BeamSpacing._100) {
                    HStack(spacing: BeamSpacing._40) {
                        CheckboxView(checked: $checkPassword)
                        Text("Passwords")
                    }
                    HStack(spacing: BeamSpacing._40) {
                        CheckboxView(checked: $checkHistory)
                        Text("History")
                    }
                }
            }
            .font(BeamFont.regular(size: 10).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
        }
    }
}

struct OnboardingImportsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingImportsView()
    }
}
