//
//  AdvancedPreferencesPrivateKeys.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI
import BeamCore

struct AdvancedPreferencesPrivateKeys: View {
    @State private var privateKeys = [String: String]()
    @State private var passwordSanityReport = ""

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row(hasDivider: true) {
                Text("Encryption keys")
            } content: {
                VStack(alignment: .leading) {
                    Button("Delete all private keys") {
                        deleteAllPrivateKeys()
                    }.foregroundColor(Color.red)
                    if AuthenticationManager.shared.isAuthenticated {
                        if privateKeys.isEmpty {
                            Button("Migrate old private key to current account") {
                                migrateOldPrivateKeyToCurrentAccount()
                            }
                        } else {
                            ScrollView([.vertical], showsIndicators: true) {
                                ForEach(privateKeys.sorted(by: >), id: \.key) { key, value in
                                    VStack(alignment: .leading) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(key)
                                            Spacer()
                                        }
                                        Button("Verify") {
                                            verifyPrivateKey(forAccount: key)
                                        }
                                        Button("Delete") {
                                            deletePrivateKey(forAccount: key)
                                        }.foregroundColor(Color.red)
                                        Button("Reset") {
                                            resetPrivateKey(forAccount: key)
                                        }.foregroundColor(Color.red)
                                        TextField("\(key):", text: Binding<String>(get: {
                                            EncryptionManager.shared.readPrivateKey(for: key)?.asString() ?? "No private key"
                                        }, set: { value, _ in
                                            _ = try? EncryptionManager.shared.replacePrivateKey(for: key, with: value)
                                            updateKeys()
                                        }))
                                        Separator(horizontal: true, hairline: true)
                                    }.frame(width: 440)
                                }
                            }.frame(width: 440, height: 240)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(BeamColor.Niobium.swiftUI, lineWidth: 1)
                                        .frame(width: 450, height: 250)
                                        .padding()
                                )
                        }
                    } else {
                        Text("You are not Authenticated")
                    }
                }
            }

            Settings.Row {
                Text("Local Encryption Key")
            } content: {
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Local private key (only used to store local contents)")
                        Spacer()
                        Button("Verify") {
                            verifyLocalPrivateKey()
                        }
                        Button("Reset") {
                            resetLocalPrivateKey()
                        }.foregroundColor(Color.red)
                    }.frame(width: 450)
                    TextField("local private key:", text: Binding<String>(get: {
                        Persistence.Encryption.localPrivateKey ?? ""
                    }, set: { value, _ in
                        Persistence.Encryption.localPrivateKey = value
                        updateKeys()
                    })).frame(width: 450)
                    Spacer()

                    VStack(alignment: .leading) {
                        Text("The historical private key:")
                        TextField("privateKey", text: Binding<String>(get: {
                            Persistence.Encryption.privateKey ?? ""
                        }, set: { value, _ in
                            Persistence.Encryption.privateKey = value
                        }))
                    }.frame(width: 450)
                    Spacer()

                    Button("Verify Passwords") {
                        verifyPasswords()
                    }
                    Text(passwordSanityReport)
                        .frame(width: 450)
                }
            }
        }.onAppear {
            if AuthenticationManager.shared.isAuthenticated {
                updateKeys()
            }
        }
    }

    private func updateKeys() {
        var pkeys = [String: String]()
        for email in EncryptionManager.shared.accounts {
            pkeys[email] = EncryptionManager.shared.readPrivateKey(for: email)?.asString() ?? ""
        }
        privateKeys = pkeys
    }

    func migrateOldPrivateKeyToCurrentAccount() {
        _ = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
        updateKeys()
    }

    func deleteAllPrivateKeys() {
        UserAlert.showAlert(message: "Are you sure you want to delete ALL private keys?", informativeText: "Erase all private keys", buttonTitle: "Cancel", secondaryButtonTitle: "Erase Private Keys", secondaryButtonAction: {
            EncryptionManager.shared.resetPrivateKeys(andMigrateOldSharedKey: false)
            updateKeys()
        }, style: .critical)
    }

    func verifyPrivateKey(forAccount key: String) {
        do {
            let string = "This is the clear text with accent é 🤤"
            let PKey = EncryptionManager.shared.privateKey(for: key)
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

    func deletePrivateKey(forAccount key: String) {
        UserAlert.showAlert(message: "Are you sure you want to erase the private key for '\(key)'?", buttonTitle: "Cancel", secondaryButtonTitle: "Erase Private Key", secondaryButtonAction: {
            EncryptionManager.shared.clearPrivateKey(for: key)
            updateKeys()
        }, style: .critical)
    }

    func resetPrivateKey(forAccount key: String) {
        UserAlert.showAlert(message: "Are you sure you want to reset the private key for '\(key)'?", buttonTitle: "Cancel", secondaryButtonTitle: "Reset Private Key", secondaryButtonAction: {
            EncryptionManager.shared.clearPrivateKey(for: key)
            let pkey = EncryptionManager.shared.generateKey()
            do {
                try EncryptionManager.shared.replacePrivateKey(for: key, with: pkey.asString())
            } catch {
                Logger.shared.logError("Error while replacing the private key for \(key) with \(pkey.asString())", category: .encryption)
            }
            updateKeys()
        }, style: .critical)
    }

    // MARK: - Local PK
    func resetLocalPrivateKey() {
        UserAlert.showAlert(message: "Are you sure you want to reset the local private key?", buttonTitle: "Cancel", secondaryButtonTitle: "Reset Local Private Key", secondaryButtonAction: {
            let pkey = EncryptionManager.shared.generateKey()
            Persistence.Encryption.localPrivateKey = pkey.asString()
            updateKeys()
        }, style: .critical)
    }

    func verifyLocalPrivateKey() {
        do {
            let string = "This is the clear text with accent é 🤤"
            let PKey = EncryptionManager.shared.localPrivateKey()
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
            let sanityDigest = try PasswordManager.shared.sanityDigest()
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
