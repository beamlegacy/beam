//
//  OnboardingImportsView.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import SwiftUI
import BeamCore

struct OnboardingImportsView: View {
    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback?

    @State private var checkHistory = false
    @State private var checkPassword = false
    @State private var isLoading = false

    @State var availableSources: [ImportSource] = [.safari, .passwordsCSV]
    @State var selectedSource: ImportSource = .safari
    @State private var passwordImportURL: URL?
    @State private var historyImportURL: URL?

    private let iconCache = ImportSourceIconCache()
    private func iconImage(for source: ImportSource) -> some View {
        Group {
            if let iconImage = iconCache.getIconForSource(source) {
                Image(nsImage: iconImage).resizable().scaledToFill()
            } else {
                Icon(name: source.icon, color: BeamColor.LightStoneGray.swiftUI)
            }
        }
        .frame(width: 16, height: 16, alignment: .center)
    }

    @State private var showNativePickerAfterAnimation = false
    private var picker: some View {
        HStack(spacing: BeamSpacing._40) {
            Picker("", selection: $selectedSource) {
                ForEach(availableSources, id: \.self) { source in
                    if source == .passwordsCSV {
                        Divider()
                    }
                    HStack {
                        iconImage(for: source)
                        Text(source.rawValue)
                    }
                }
            }
            .pickerStyle(MenuPickerStyle())
            .opacity(showNativePickerAfterAnimation ? 1.0 : 0.0)
            .overlay(
                ZStack(alignment: .leading) {
                    Rectangle().fill(BeamColor.Generic.background.swiftUI)
                        .padding(-4)
                    HStack(spacing: 0) {
                        iconImage(for: selectedSource)
                        ButtonLabel(selectedSource.rawValue, variant: .dropdown, customStyle: .init(disableAnimations: false))
                    }
                    .padding(.leading, 12)
                }.allowsHitTesting(false)
            )
            .offset(x: -12, y: 0)
        }
        .padding(.vertical, 3)
        .onAppear {
            // Picker is not animating correctly with step transition, hiding it at first.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                showNativePickerAfterAnimation = true
            }
        }
    }

    private var passwordCSVContent: some View {
        VStack(alignment: .leading, spacing: BeamSpacing._100) {
            Text("Export your passwords from other browsers or password manager as a CSV file.")
            Text("Click the Import Passwords button and select the CSV file.")
        }
        .frame(alignment: .top)
    }

    private var browsersContent: some View {
        VStack(alignment: .leading, spacing: BeamSpacing._100) {
            HStack(spacing: BeamSpacing._40) {
                CheckboxView(checked: $checkPassword.onChange({ newValue in
                    if newValue {
                        importPasswords()
                    } else {
                        passwordImportURL = nil
                    }
                    updateActions()
                }))
                Text("Passwords")
            }.onTapGesture {
                importPasswords()
            }
            HStack(spacing: BeamSpacing._40) {
                CheckboxView(checked: $checkHistory.onChange({ newValue in
                    if newValue {
                        importHistory()
                    } else {
                        historyImportURL = nil
                    }
                    updateActions()
                }))
                Text("History") + Text(" - not supported yet").foregroundColor(BeamColor.Generic.subtitle.swiftUI)
            }.onTapGesture {
                importHistory()
            }.disabled(true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                OnboardingView.LoadingView(message: "Importing your data...")
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            } else {
                OnboardingView.TitleText(title: "Import your data")
                VStack(alignment: .leading, spacing: 0) {
                    picker
                    Separator(horizontal: true)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: BeamSpacing._100) {
                        if selectedSource == .passwordsCSV {
                            passwordCSVContent
                        } else {
                            browsersContent
                        }
                    }
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .frame(minHeight: 80, alignment: .top)
                }
            }
        }
        .background(KeyEventHandlingView(handledKeyCodes: [.enter, .space], firstResponder: true, onKeyDown: { event in
            if event.keyCode == KeyCode.space.rawValue {
                finish?(nil)
            } else {
                startImports()
            }
        }))
        .frame(width: 310)
        .onAppear {
            updateAvailableSources()
            updateActions()
        }
        .onChange(of: selectedSource) { _ in
            checkPassword = false
            passwordImportURL = nil
            checkHistory = false
            historyImportURL = nil
            updateActions()
        }
    }

    private func updateAvailableSources() {
        availableSources = ImportSource.allCases.filter { $0.isAvailable }
    }
    private let skipActionId = UUID()
    private let importActionId = UUID()
    private func updateActions() {
        if isLoading {
            actions = []
            return
        }
        let importEnable = selectedSource == .passwordsCSV || passwordImportURL != nil || historyImportURL != nil
        let importTitle = selectedSource == .passwordsCSV ? "Import Passwords" : "Import"
        actions = [
            .init(id: skipActionId, title: "Skip", enabled: true, secondary: true),
            .init(id: importActionId, title: importTitle, enabled: importEnable) {
                startImports()
                return false
            }
        ]
    }
}

// MARK: - Imports Actions
extension OnboardingImportsView {

    private func importPasswords() {
        openFilePanel(title: "Select a csv file exported from \(selectedSource.rawValue)") { url in
            passwordImportURL = url
            checkPassword = url != nil
            updateActions()
        }
    }

    private func importHistory() {
        openFilePanel(title: "Select a csv file exported from \(selectedSource.rawValue)") { url in
            historyImportURL = url
            checkHistory = url != nil
            updateActions()
        }
    }

    private func openFilePanel(title: String, completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canDownloadUbiquitousContents = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["csv", "txt"]
        openPanel.title = title
        openPanel.begin { result in
            openPanel.close()
            completion(result == .OK ? openPanel.url : nil)
        }
    }

    private func startImports(directPasswordsCSVURL: URL? = nil) {
        if selectedSource == .passwordsCSV && directPasswordsCSVURL == nil {
            openFilePanel(title: "Select a csv file exported") { url in
                guard let url = url else { return }
                startImports(directPasswordsCSVURL: url)
            }
            return
        }
        guard !isLoading && (passwordImportURL != nil || historyImportURL != nil || directPasswordsCSVURL != nil) else { return }
        isLoading = true
        updateActions()
        let startTime = BeamDate.now
        if let passwordURL = passwordImportURL ?? directPasswordsCSVURL {
            do {
                try PasswordImporter.importPasswords(fromCSV: passwordURL)
            } catch {
                Logger.shared.logError("Error importing passwords \(String(describing: error))", category: .passwordManager)
            }
        }
        if historyImportURL != nil {
            // Waiting for import history implementation https://gitlab.com/beamgroup/beam/-/merge_requests/1586
        }
        let delay = Int(max(0, 2 + startTime.timeIntervalSinceNow.rounded(.up)))
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
            finish?(nil)
        }
    }
}

// MARK: - Sources
extension OnboardingImportsView {
    class ImportSourceIconCache {
        private var cache: [ImportSource: NSImage] = [:]
        private let iconSize: CGFloat = 16
        func getIconForSource(_ source: ImportSource) -> NSImage? {
            if let image = cache[source] {
                return image
            }
            if let url = source.appURL {
                let images = NSWorkspace.shared.icon(forFile: url.path)
                if let rep = images.bestRepresentation(for: NSRect(x: 0, y: 0, width: iconSize, height: iconSize), context: nil, hints: nil) {
                    let image = NSImage(size: rep.size)
                    image.addRepresentation(rep)
                    cache[source] = image
                    return image
               }
            }
            return nil
        }
    }

    enum ImportSource: String, CaseIterable, Identifiable {
        var id: String { rawValue }

        case safari = "Safari"
        case chrome = "Google Chrome"
        case firefox = "Mozilla Firefox"
        case passwordsCSV = "Passwords CSV File"

        var icon: String {
            switch self {
            case .safari, .chrome, .firefox:
                return "field-web"
            case .passwordsCSV:
                return "autofill-password_xs"
            }
        }

        var appURL: URL? {
            switch self {
            case .safari:
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.safari")
            case .chrome:
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome")
            case .firefox:
                return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.mozilla.firefox")
            case .passwordsCSV:
                return nil
            }
        }

        var isAvailable: Bool {
            switch self {
            case .passwordsCSV:
                return true
            case .safari, .chrome, .firefox:
                return appURL != nil
            }
        }
    }
}

struct OnboardingImportsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingImportsView(actions: .constant([]), finish: nil, selectedSource: .safari)
            .frame(width: 600, height: 600)
    }
}
