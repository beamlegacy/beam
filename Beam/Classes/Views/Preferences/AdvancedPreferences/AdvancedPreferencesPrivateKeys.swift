//
//  AdvancedPreferencesPrivateKeys.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI
import BeamCore

struct AdvancedPreferencesPrivateKeys: View {
    @State private var passwordSanityReport = ""

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Local Encryption Key")
            } content: {
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Local private key (used to encrypt saved passwords)")
                        Spacer()
                        Button("Verify") {
                            verifyLocalPrivateKey()
                        }
                        Button("Reset") {
                            resetLocalPrivateKey()
                        }.foregroundColor(Color.red)
                    }.frame(width: 450)
                    TextField("local private key:", text: Binding<String>(get: {
                        (try? EncryptionManager.shared.loadLocalPrivateKey()) ?? ""
                    }, set: { value, _ in
                        try? EncryptionManager.shared.storeLocalPrivateKey(value)
                    })).frame(width: 450)
                    Spacer()

                    Button("Verify Passwords") {
                        verifyPasswords()
                    }
                    Text(passwordSanityReport)
                        .frame(width: 450)
                }
            }
        }
    }

    func resetLocalPrivateKey() {
        UserAlert.showAlert(message: "Are you sure you want to reset the local private key? This will make all your passwords unreadable.", buttonTitle: "Cancel", secondaryButtonTitle: "Reset Local Private Key", secondaryButtonAction: {
            let pkey = EncryptionManager.shared.generateKey()
            try? EncryptionManager.shared.storeLocalPrivateKey(pkey.asString())
        }, style: .critical)
    }

    func verifyLocalPrivateKey() {
        do {
            let string = "This is the clear text with accent é 🤤"
            let PKey = try EncryptionManager.shared.localPrivateKey()
            let encryptedString = try EncryptionManager.shared.encryptString(string, PKey)
            var decryptedString: String?

            if let encryptedString = encryptedString {
                decryptedString = try EncryptionManager.shared.decryptString(encryptedString, PKey)

                if decryptedString == string, encryptedString != string {
                    UserAlert.showMessage(message: "Encryption",
                                          informativeText: "Encryption worked ✅ Clear text is \(string) and encrypted data is \(encryptedString)")

                    return
                }
            }

            UserAlert.showError(message: "Encryption",
                                informativeText: "This encryption didn't work, key is corrupted!")
        } catch {
            UserAlert.showError(message: "Encryption", error: error)
        }
    }

    private func verifyPasswords() {
        do {
            let sanityDigest = try BeamData.shared.passwordManager.sanityDigest()
            passwordSanityReport = sanityDigest.description
        } catch {
            passwordSanityReport = error.localizedDescription
        }
    }
}

struct AdvancedPreferencesPrivateKeys_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesPrivateKeys()
    }
}
