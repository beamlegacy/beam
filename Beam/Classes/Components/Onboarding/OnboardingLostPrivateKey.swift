//
//  OnboardingLostPrivateKey.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 05/02/2022.
//

import SwiftUI

struct OnboardingLostPrivateKey: View {
    var finish: OnboardingView.StepFinishCallback

    private var destructiveCenteredVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.destructive.style
        style.icon = nil
        style.textAlignment = .center
        return .custom(style)
    }

    var body: some View {
        VStack {
            OnboardingView.TitleText(title: "Lost private key")
            VStack(alignment: .leading) {
                Text("If you have lost your private key, the only way to gain back access to your account is to permanently delete all your data.")
                    .lineLimit(3)
                    .frame(width: 290)
                    .font(BeamFont.medium(size: 14).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .padding(.bottom, 20)
                Text("This operation cannot be undone.")
                    .frame(width: 290, alignment: .leading)
                    .font(BeamFont.bold(size: 14).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            }.padding(.bottom, 40)
            ActionableButton(text: "Erase all data", defaultState: .normal, variant: destructiveCenteredVariant, minWidth: 280, height: 34) {
                // Two alerts and delete
                UserAlert.showMessage(message: "Erase all data", informativeText: "This operation cannot be undone.", buttonTitle: "Erase all data", secondaryButtonTitle: "Cancel") {
                    UserAlert.showMessage(message: "Are you sure you want to erase all your beam data?", informativeText: "This operation cannot be undone.", buttonTitle: "Yes, Erase All Data", secondaryButtonTitle: "Cancel") {
                        let semaphore = DispatchSemaphore(value: 0)
                        // Delete All Local Content && Remote data
                        AppDelegate.main.deleteAllData(includedRemote: false)
                        _ = try? BeamObjectManager().deleteAll(nil) { _ in
                            semaphore.signal()
                        }
                        semaphore.wait()
                        finish(nil)
                    }
                }
            }
        }
    }
}

struct OnboardingLostPrivateKey_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingLostPrivateKey { _ in }
    }
}
