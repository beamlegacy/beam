//
//  OnboardingMinimalWelcomeView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 22/09/2022.
//

import SwiftUI
import BeamCore

struct OnboardingMinimalWelcomeView: View {
    var finish: OnboardingView.StepFinishCallback

    private var secondaryCenteredVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.primaryBeam.style
        style.icon = .init(name: "shortcut-return")
        style.textAlignment = .center
        return .custom(style)
    }

    var body: some View {
        VStack {
            VStack(spacing: BeamSpacing._200) {
                AppIcon()
                    .frame(width: 52, height: 52)
                OnboardingView.TitleText(title:"Welcome to Beam")
            }
            ActionableButton(text: loc("Continue"), defaultState: .normal, variant: secondaryCenteredVariant, minWidth: 207, height: 34, invertBlendMode: true) {
                finish(nil)
            }
        }.background(KeyEventHandlingView(handledKeyCodes: [.enter, .space], firstResponder: true, onKeyDown: { event in
            finish(nil)
        }))
    }
}

struct OnboardingMinimalWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingMinimalWelcomeView { _ in }
    }
}
