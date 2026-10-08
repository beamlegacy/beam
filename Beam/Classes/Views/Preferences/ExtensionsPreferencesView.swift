//
//  ExtensionsPreferencesView.swift
//  Beam
//

import SwiftUI
import WebKit

@available(macOS 15.4, *)
struct ExtensionsPreferencesView: View {
    @ObservedObject private var manager = WebExtensionsManager.shared
    @State private var availableAppExtensions: [WebExtensionsManager.AvailableAppExtension] = []
    @State private var errorMessage: IdentifiableString?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if manager.installedExtensions.isEmpty {
                    Text("No extensions installed. Add a Safari extension from an installed app, or load an unpacked extension.")
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(manager.installedExtensions) { installed in
                                ExtensionRow(installed: installed, errorMessage: $errorMessage)
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(height: 300)
            .background(BeamColor.Generic.background.swiftUI)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(BeamColor.Generic.separator.swiftUI))

            HStack(alignment: .firstTextBaseline) {
                Menu("Add Extension") {
                    if !availableAppExtensions.isEmpty {
                        Section(header: Text("Safari Extensions")) {
                            ForEach(availableAppExtensions) { appExtension in
                                Button(appExtension.name) {
                                    install { try await manager.installAppExtension(at: appExtension.path) }
                                }
                            }
                        }
                        Divider()
                    }
                    Button("Load Extension Folder or ZIP…") {
                        chooseExtensionResources()
                    }
                }
                .fixedSize()
                Spacer()
                Text("Features relying on the extension’s companion app (native messaging) are not available.")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
            }
        }
        .padding(20)
        .frame(width: PreferencesManager.contentWidth)
        .onAppear(perform: refreshAvailableAppExtensions)
        .onReceive(manager.$installedExtensions) { _ in refreshAvailableAppExtensions() }
        .alert(item: $errorMessage) { Alert(title: Text("Couldn’t add the extension"), message: Text($0.string)) }
    }

    private func refreshAvailableAppExtensions() {
        DispatchQueue.main.async {
            availableAppExtensions = manager.availableAppExtensions()
        }
    }

    private func install(_ operation: @escaping () async throws -> Void) {
        Task { @MainActor in
            do {
                try await operation()
            } catch WebExtensionsManager.Error.cancelled {
                return
            } catch {
                errorMessage = IdentifiableString(error.localizedDescription)
            }
        }
    }

    private func chooseExtensionResources() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.zip, .folder]
        openPanel.message = "Select an unpacked extension folder (containing manifest.json) or a ZIP archive"
        openPanel.begin { result in
            guard result == .OK, let url = openPanel.url else { return }
            install { try await manager.installExtensionResources(at: url) }
        }
    }
}

@available(macOS 15.4, *)
private struct ExtensionRow: View {
    let installed: WebExtensionsManager.InstalledExtension
    @Binding var errorMessage: IdentifiableString?

    private var manager: WebExtensionsManager { .shared }
    private var webExtension: WKWebExtension? { installed.context?.webExtension }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let icon = webExtension?.icon(for: CGSize(width: 32, height: 32)) {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "puzzlepiece.extension").resizable().scaledToFit()
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(installed.displayName).font(BeamFont.medium(size: 13).swiftUI)
                    if let version = webExtension?.displayVersion {
                        Text(version).font(BeamFont.regular(size: 11).swiftUI).foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    }
                }
                if let description = webExtension?.displayDescription {
                    Text(description).font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        .lineLimit(2)
                }
                if let loadError = installed.loadError {
                    Text(loadError.localizedDescription).font(BeamFont.regular(size: 11).swiftUI).foregroundColor(.red).lineLimit(2)
                }
                HStack(spacing: 12) {
                    Toggle("Enabled", isOn: Binding(get: { installed.record.isEnabled },
                                                    set: { manager.setEnabled($0, for: installed.id) }))
                    Toggle("Allow in Incognito", isOn: Binding(get: { installed.record.allowsPrivateBrowsing },
                                                               set: { manager.setAllowsPrivateBrowsing($0, for: installed.id) }))
                }
                .toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 12).swiftUI)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if webExtension?.hasOptionsPage == true {
                    Button("Settings…") { manager.openOptionsPage(for: installed.id) }
                }
                Button("Remove") { confirmRemoval() }
            }
        }
        .padding(12)
    }

    private func confirmRemoval() {
        let alert = NSAlert()
        alert.messageText = "Remove “\(installed.displayName)”?"
        alert.informativeText = "Its data stored in Beam will be deleted."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await manager.uninstall(installed.id) }
    }
}
