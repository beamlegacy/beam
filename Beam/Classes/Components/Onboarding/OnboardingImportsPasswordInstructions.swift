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

        private func bulletPoints(_ texts: [String], startIndex: Int = 1) -> some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                ForEach(Array(texts.enumerated()), id: \.1) { (index, t) in
                    bulletPoint(t, index: startIndex + index)
                }
            }
        }

        private func bulletPoint(_ text: String, index: Int) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                indexIcon(index)
                Text(text)
            }
        }

        private func indexIcon(_ index: Int) -> some View {
            Text("\(index)")
                .foregroundColor(BeamColor.AlphaGray.swiftUI)
                .font(BeamFont.medium(size: 11).swiftUI)
                .frame(width: 20, height: 20)
        }

        private var safariInstructions: some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                bulletPoints([
                    "Open Safari Preferences -> Passwords.",
                    "Click on “•••” and choose “Export...”",
                    "Click on Choose CSV File button and select the exported CSV file."
                ])
            }
        }

        private var safariOldInstructions: some View {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    indexIcon(1)
                    Text("Download and Launch ") +
                    Text("Beam Passwords Importer").font(BeamFont.medium(size: 11).swiftUI).bold().underline()

                }
                .onTapGesture {
                    openExternalURL("https://github.com/franklefebvre/SafariPasswordExporter", title: "Beam Passwords Importer")
                }
                bulletPoints([
                    "Give it the Accessibility permission in System Preferences",
                    "Keep Safari in the foreground while the import ongoing. Don’t touch anything",
                    "Click on Choose CSV File button and select the exported CSV file."
                ], startIndex: 2)
            }
        }

        private var firefoxInstructions: some View {
            bulletPoints([
                "Open Firefox Preferences -> Privacy & Security -> Saved Logins.",
                "Click on “•••” and choose “Export logins...”",
                "Click on Choose CSV File button and select the exported CSV file."
            ])
        }

        private var anyCSVInstructions: some View {
            bulletPoints([
                "Export your passwords from other browsers or password managers as a CSV file.",
                "Click the “Choose CSV File” button and select the CSV file."
            ])
        }

        private var secondaryActionVariant: ActionableButtonVariant {
            var style = ActionableButtonVariant.secondary.style
            style.icon = nil
            return .custom(style)
        }

        private var fileSelector: some View {
            let fileName = selectedURL?.lastPathComponent
            return ActionableButton(text: fileName ?? "Choose CSV File", variant: secondaryActionVariant, height: 26) {
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
                VStack(alignment: .leading, spacing: BeamSpacing._160) {
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
