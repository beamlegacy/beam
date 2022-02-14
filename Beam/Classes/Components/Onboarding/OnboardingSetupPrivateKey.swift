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
                VStack {
                    OnboardingView.TitleText(title: "Enter your private key")
                    Text("To sync your account, please import your private key or drag and drop it on this window.")
                        .lineLimit(3)
                        .frame(width: 290)
                        .font(BeamFont.medium(size: 14).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .padding(.bottom, 40)
                    VStack(spacing: 12) {
                        ActionableButton(text: "Import Private Key...", defaultState: .normal, variant: secondaryCenteredVariant, minWidth: 280, height: 34) {
                            importBeamKey()
                        }
                        Text("“.beamkey” is the file extension")
                            .font(BeamFont.medium(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
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

    private func updateActions() {
        if loadingState != nil {
            actions = []
        } else {
            actions = [
                .init(id: "beamkey_import_continue", title: "Continue", enabled: false, onClick: {
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

    private func importBeamKey(fileUrl: String? = nil) {
        EncryptionManager.shared.importKeyFromFile(atPath: fileUrl) { key in
            guard let key = key else {
                UserAlert.showMessage(message: "Incorrect private key file", informativeText: "This private key file is either corrupted or damaged.", buttonTitle: nil)
                return
            }

            try? EncryptionManager.shared.replacePrivateKey(for: Persistence.emailOrRaiseError(), with: key.asString())

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
}

struct OnboardingSetupPrivateKey_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSetupPrivateKey(actions: .constant([])) { _ in }
    }
}
