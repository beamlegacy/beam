//
//  OnboardingSaveEncryptionView.swift
//  Beam
//
//  Created by Remi Santos on 02/06/2021.
//

import SwiftUI
import BeamCore

struct OnboardingSaveEncryptionView: View {
    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback?

    @State private var isLoading = false

    @State private var key = "..."
    @State var encryptionKeyIsCopied = false

    private let defaultContentWidth: Double = 290
    private let transition = AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                              removal: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08)))

    private var iconButtonStyle: ButtonLabelStyle {
        var style = ButtonLabelStyle.tinyIconStyle
        style.iconSize = 12
        style.verticalPadding = 3
        style.horizontalPadding = style.verticalPadding
        return style
    }

    private var keyField: some View {
        HStack(spacing: 0) {
            HStack(spacing: BeamSpacing._100) {
                Button {
                    encryptionKeyIsCopied.toggle()

                    copyKeyToPasteboard()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        encryptionKeyIsCopied.toggle()
                    }
                } label: {
                    Text(key)
                }.buttonStyle(.plain)
                    .overlay(
                        ZStack(alignment: .trailing) {
                            if encryptionKeyIsCopied {
                                Tooltip(title: "Encryption Key Copied !")
                                    .fixedSize()
                                    .offset(x: 0, y: -35)
                                    .transition(transition)
                            }
                        })
            }
            .font(BeamFont.medium(size: 13).swiftUI)
            .foregroundColor(BeamColor.Corduroy.swiftUI)
            .padding(BeamSpacing._100)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(BeamColor.Mercury.swiftUI, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BeamSpacing._100)
    }

    private func underlineSubtitleRange(text: String) -> [Range<String.Index>] {
        text.ranges(of: loc("end-to-end encrypted", comment: "underline part of onboarding save encryption key subtitle"))
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                OnboardingView.LoadingView()
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            } else {
                OnboardingView.TitleText(title: loc("Save your private key"))
                VStack(alignment: .center, spacing: BeamSpacing._400) {
                    StyledText(verbatim: loc("Your beam data is end-to-end encrypted\nwith your private key:"))
                        .style(.underline(), ranges: underlineSubtitleRange)
                        .frame(maxWidth: defaultContentWidth, alignment: .leading)

                    keyField

                    VStack(alignment: .leading, spacing: 0) {
                        Text(loc("The key can be required when signing in from a new device.\n"))
                        +
                        Text(loc("Save this key in a safe place. Do not lose it.\nBeam will not be able to reset it for you if you lose it."))
                            .font(BeamFont.semibold(size: 14).swiftUI)
                    }
                    .frame(maxWidth: defaultContentWidth, alignment: .leading)
                }
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .font(BeamFont.regular(size: 14).swiftUI)
            }
        }
        .background(KeyEventHandlingView(handledKeyCodes: [.enter], firstResponder: true, onKeyDown: { event in
            if event.keyCode == KeyCode.enter.rawValue {
                saveKeyToFile()
            }
        }))
        .onAppear {
            key = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
            updateActions()
        }
    }

    private func updateActions() {
        actions = [
            .init(title: "Save it now!", enabled: true, customWidth: 185, onClick: {
                saveKeyToFile()
                return false
            })
        ]
    }

    private func copyKeyToPasteboard() {
        EncryptionManager.shared.copyKeyToPasteboard()
    }

    private func saveKeyToFile() {
        EncryptionManager.shared.saveKeyToFile { _ in
            finish?(nil)
        }
    }
}

struct OnboardingSaveEncryptionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSaveEncryptionView(actions: .constant([]), finish: nil)
            .padding(20)
            .background(BeamColor.Generic.background.swiftUI)
    }
}
