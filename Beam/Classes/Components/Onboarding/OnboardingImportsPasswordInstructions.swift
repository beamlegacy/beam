//
//  OnboardingImportsPasswordInstructions.swift
//  Beam
//
//  Created by Remi Santos on 21/12/2021.
//

import SwiftUI

extension OnboardingImportsView {
    struct OnboardingImportsPasswordInstructions: View {
        var source: ImportSource
        @Binding var selectedURL: URL?
        var panelOpener: ((String, @escaping (URL?) -> Void) -> Void)?

        private let vStackSpacing: CGFloat = 4
        private func bulletPoint(_ text: String) -> some View {
            HStack(spacing: 1) {
                Icon(name: "editor-bullet", width: 20, color: BeamColor.AlphaGray.swiftUI)
                Text(text)
            }
        }

        private var safariInstructions: some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                bulletPoint("Open Safari Preferences -> Passwords.")
                bulletPoint("Click on “•••” and choose “Export...”")
                bulletPoint("Click on Choose CSV File button and select the exported CSV file.")
            }
        }

        private var safariOldInstructions: some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                HStack(spacing: 1) {
                    Icon(name: "editor-bullet", width: 20, color: BeamColor.AlphaGray.swiftUI)
                    Text("Download and Launch ") +
                    Text("Beam Passwords Importer").font(BeamFont.medium(size: 11).swiftUI).bold().underline()

                }
                .onTapGesture {
                    openExternalURL("https://github.com/franklefebvre/SafariPasswordExporter", title: "Beam Passwords Importer")
                }
                bulletPoint("Give it the Accessibility permission in System Preferences")
                bulletPoint("Keep Safari in the foreground while the import ongoing. Don’t touch anything")
                bulletPoint("Click on Choose CSV File button and select the exported CSV file.")
            }
        }

        private var firefoxInstructions: some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                bulletPoint("Open Firefox Preferences -> Privacy & Security -> Saved Logins.")
                bulletPoint("Click on “•••” and choose “Export logins...”")
                bulletPoint("Click on Choose CSV File button and select the exported CSV file.")
            }
        }

        private var anyCSVInstructions: some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                bulletPoint("Export your passwords from other browsers or password managers as a CSV file.")
                bulletPoint("Click the “Choose CSV File” button and select the CSV file.")
            }
        }

        private var fileSelector: some View {
            let fileName = selectedURL?.lastPathComponent
            return ButtonLabel(fileName ?? "Choose CSV File", icon: fileName != nil ? "tabs-file" : nil, variant: .dropdown) {
                panelOpener?("Select a csv file exported from \(source.rawValue)") { url in
                    selectedURL = url
                }
            }
            .padding(.top, 9)
        }

        private func openExternalURL(_ urlString: String, title: String) {
            guard let url = URL(string: urlString), let safariURL = ImportSource.safariOld.appURL else { return }
            NSWorkspace.shared.open([url], withApplicationAt: safariURL, configuration: NSWorkspace.OpenConfiguration())
        }

        var body: some View {
            Group {
                VStack(alignment: .leading, spacing: 3) {
                    if source == .safari {
                        safariInstructions
                    } else if source == .safariOld {
                        safariOldInstructions
                    } else if source == .firefox {
                        firefoxInstructions
                    } else if source == .passwordsCSV {
                        anyCSVInstructions
                    }
                    fileSelector
                }
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .font(BeamFont.regular(size: 11).swiftUI)
                .lineSpacing(2)
            }
        }
    }
}
