//
//  OnboardingSetupPrivateKey.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 04/02/2022.
//

import SwiftUI

struct OnboardingSetupPrivateKey: View {
    @Binding var actions: [OnboardingManager.StepAction]
    @EnvironmentObject private var onboardingManager: OnboardingManager
    var finish: OnboardingView.StepFinishCallback

    private enum LoadingState: Equatable {
        case gettingInfos
    }
    @State private var loadingState: LoadingState?
    @State private var privateKey: String = ""
    @State private var isPrivateKeyEditing: Bool = false

    private var secondaryCenteredVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.secondary.style
        style.icon = nil
        style.textAlignment = .center
        return .custom(style)
    }

    var body: some View {
        VStack {
            if loadingState == .gettingInfos {
                OnboardingView.LoadingView()
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            } else {
                VStack(spacing: 0) {
                    OnboardingView.TitleText(title: "Enter your private key")
                    Text("Import the Private Key file you saved when creating your account or paste your private key below to sync your account.")
                        .lineLimit(3)
                        .frame(width: 290)
                        .font(BeamFont.regular(size: 14).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .padding(.bottom, 40)
                    VStack(spacing: 14) {
                        keyField
                            .frame(width: 290)
                        Text("or")
                            .font(BeamFont.medium(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
                        ActionableButton(text: "Import beamkey file...", defaultState: .normal, variant: secondaryCenteredVariant, minWidth: 290, height: 26) {
                            importBeamKey()
                        }
                    }.padding(.bottom, 42)
                    ButtonLabel("I can’t find my private key", customStyle: .init(font: BeamFont.regular(size: 13).swiftUI, activeBackgroundColor: .clear, disableAnimations: false)) {
                        finish(.init(type: .lostPrivateKey))
                    }
                }.onDrop(of: ["public.file-url"], isTargeted: nil, perform: { items in
                    return performDrop(items: items)
                })
            }
        }.onAppear {
            updateActions()
        }
    }

    private var keyField: some View {
        VStack(spacing: 0) {
            BeamTextField(text: $privateKey,
                          isEditing: $isPrivateKeyEditing,
                          placeholder: "Paste your private key",
                          font: BeamFont.regular(size: 14).nsFont,
                          textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor,
                          secure: false,
                          onTextChanged: { _ in
                updateActions()
            }, onCommit: { _ in
                importBeamKey(privateKey)
            }, onTab: {
                isPrivateKeyEditing = false
                return true
            }).frame(height: 40)

            Separator(horizontal: true, color: BeamColor.Nero)
        }
    }

    private func updateActions() {
        if loadingState != nil {
            actions = []
        } else {
            actions = [
                .init(id: "beamkey_import_continue", title: "Continue", enabled: !privateKey.isEmpty, onClick: {
                    importBeamKey(privateKey)
                    return false
                })
            ]
        }
    }

    private func performDrop(items: [NSItemProvider]) -> Bool {
        guard let item = items.first else { return false }
        item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
            if error != nil {
                UserAlert.showMessage(message: "Incorrect private key file", informativeText: "This private key file is either corrupted or damaged.", buttonTitle: nil)
                return
            }
            DispatchQueue.main.async {
                if let urlData = urlData as? Data {
                    let fileUrl = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    if fileUrl.pathExtension == "beamkey" {
                        importBeamKey(fileUrl: fileUrl.string)
                    }
                }
            }
        }
        return true
    }

    private func importBeamKey(_ keyStr: String) {
        guard let key = EncryptionManager.shared.decodeBeamKey(keyStr) else {
            UserAlert.showMessage(message: "Incorrect private key", informativeText: "This private key is corrupted.", buttonTitle: nil)
            return
        }
        replaceAndCheck(key: key.asString())
    }

    private func importBeamKey(fileUrl: String? = nil) {
        EncryptionManager.shared.importKeyFromFile(atPath: fileUrl) { key in
            guard let key = key else {
                UserAlert.showMessage(message: "Incorrect private key file", informativeText: "This private key file is either corrupted or damaged.", buttonTitle: nil)
                return
            }
            replaceAndCheck(key: key.asString())
        }
    }

    private func replaceAndCheck(key: String) {
        try? EncryptionManager.shared.replacePrivateKey(for: Persistence.emailOrRaiseError(), with: key)

        onboardingManager.checkForPrivateKey { nextStep in
            guard nextStep != nil else {
                loadingState = .gettingInfos
                updateActions()
                return
            }
            UserAlert.showMessage(message: "This private key file doesn’t match this user account", informativeText: "You need to import the private key file matching this user account.", buttonTitle: nil)
        } syncCompletion: { result in
            switch result {
            case .success:
                finish(nil)
            default:
                break
            }
        }
    }
}

struct OnboardingSetupPrivateKey_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSetupPrivateKey(actions: .constant([])) { _ in }
    }
}
