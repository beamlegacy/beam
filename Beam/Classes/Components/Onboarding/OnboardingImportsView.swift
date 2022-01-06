//
//  OnboardingImportsView.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import SwiftUI
import BeamCore
import Combine

struct OnboardingImportsView: View {
    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback?

    @State private var checkHistory = true
    @State private var checkPassword = true
    @State private var isLoading = false

    @State var availableSources: [ImportSource] = [.safari, .passwordsCSV]
    @State var selectedSource: ImportSource = .safari
    @State private var passwordImportURL: URL?

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

    @StateObject private var viewModel = ViewModel()
    private class ViewModel: ObservableObject {
        var importCancellable: AnyCancellable?
        var finishWorkItem: DispatchWorkItem?
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
        OnboardingImportsPasswordInstructions(source: selectedSource,
                                              selectedURL: $passwordImportURL,
                                              panelOpener: { title, completion in
            openFilePanel(title: title, completion: completion)
        })
    }

    private var browsersContent: some View {
        VStack(alignment: .leading, spacing: BeamSpacing._100) {
            if selectedSource.supportsHistoryImport {
                HStack(spacing: BeamSpacing._40) {
                    CheckboxView(checked: $checkHistory.onChange({ _ in
                        updateActions()
                    }))
                    Text("History")
                }.onTapGesture {
                    checkHistory.toggle()
                    updateActions()
                }
            }
            VStack(alignment: .leading, spacing: BeamSpacing._100) {
                HStack(spacing: BeamSpacing._40) {
                    CheckboxView(checked: $checkPassword)
                    Text("Passwords")
                }.onTapGesture {
                    checkPassword = true
                }
                if !selectedSource.supportsAutomaticPasswordImport {
                    OnboardingImportsPasswordInstructions(source: selectedSource,
                                                          selectedURL: $passwordImportURL,
                                                          panelOpener: { title, completion in
                        openFilePanel(title: title, completion: completion)
                    })
                        .padding(.leading, BeamSpacing._120)
                        .opacity(checkPassword ? 1 : 0)
                }
            }
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
        .onChange(of: checkPassword) { newValue in
            if !newValue {
                passwordImportURL = nil
            }
            updateActions()
        }
        .onChange(of: passwordImportURL) { _ in
            updateActions()
        }
        .onChange(of: selectedSource) { _ in
            checkPassword = true
            passwordImportURL = nil
            checkHistory = true
            updateActions()
        }
    }

    private func updateAvailableSources() {
        availableSources = ImportSource.allCases.filter { $0.isAvailable }
    }
    private let skipActionId = "skip_action"
    private let importActionId = "import_action"

    private var shoudlEnableImportButton: Bool {
        if checkPassword {
            return passwordImportURL != nil || selectedSource.supportsAutomaticPasswordImport
        } else {
            return checkHistory
        }
    }

    private func updateActions() {
        if isLoading {
            actions = []
            return
        }
        actions = [
            .init(id: skipActionId, title: "Skip", enabled: true, secondary: true),
            .init(id: importActionId, title: "Import", enabled: shoudlEnableImportButton) {
                startImports()
                return false
            }
        ]
    }
}

// MARK: - Imports Actions
extension OnboardingImportsView {

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

    private func startImports() {
        guard !isLoading && shoudlEnableImportButton else { return }
        isLoading = true
        updateActions()
        let importsManager = AppDelegate.main.data.importsManager
        if checkPassword {
            if selectedSource.supportsAutomaticPasswordImport, let passwordImporter = selectedSource.passwordImporter {
                importsManager.startBrowserPasswordImport(from: passwordImporter)
            } else if let passwordURL = passwordImportURL {
                importsManager.startBrowserPasswordImport(from: passwordURL)
            }
        }
        if checkHistory, let importer = selectedSource.historyImporter {
            importsManager.startBrowserHistoryImport(from: importer)
        }
        waitForImporterToFinish(importsManager)
    }

    private func waitForImporterToFinish(_ importsManager: ImportsManager) {
        // show the loading view at least 2s, at most 10s
        let forceFinishAfter: Int
        if importsManager.isImporting {
            let cancellable = importsManager.$isImporting.first { $0 == false }.sink { _ in
                sendFinish()
            }
            viewModel.importCancellable = cancellable
            forceFinishAfter = 10 // at most 10s
        } else {
            forceFinishAfter = 2 // at least 2s
        }
        let workItem = DispatchWorkItem {
            guard isLoading else { return }
            sendFinish()
        }
        viewModel.finishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(forceFinishAfter), execute: workItem)
    }

    private func sendFinish() {
        viewModel.finishWorkItem?.cancel()
        viewModel.finishWorkItem = nil
        viewModel.importCancellable?.cancel()
        viewModel.importCancellable = nil
        finish?(nil)
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
        case safariOld = "Safari 14 and earlier" // Safari 15.0 is the first to introduce an "Export" button in the password view.
        case chrome = "Google Chrome"
        case firefox = "Mozilla Firefox"
        case brave = "Brave Browser"
        case passwordsCSV = "Passwords CSV File"

        var icon: String {
            switch self {
            case .safari, .safariOld, .chrome, .firefox, .brave:
                return "field-web"
            case .passwordsCSV:
                return "autofill-password_xs"
            }
        }

        private var bundleIdentifier: String? {
            switch self {
            case .safari, .safariOld:
                return "com.apple.safari"
            case .chrome:
                return "com.google.Chrome"
            case .firefox:
                return "org.mozilla.firefox"
            case .brave:
                return "com.brave.Browser"
            case .passwordsCSV:
                return nil
            }
        }
        var appURL: URL? {
            guard let bundleIdentifier = bundleIdentifier else { return nil }
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }

        private var bundleVersionInfoKey: String { "CFBundleShortVersionString" }
        var isAvailable: Bool {
            switch self {
            case .passwordsCSV:
                return true
            case .chrome, .firefox, .brave:
                return appURL != nil
            case .safari, .safariOld:
                guard let url = appURL,
                      let versionString = Bundle(path: url.path)?.infoDictionary?[bundleVersionInfoKey] as? NSString
                      else { return false }
                let version = versionString.floatValue
                if self == .safari && (version >= 15.0 || version == 0.0) {
                    return true
                } else if self == .safariOld && version < 15.0 {
                    return true
                }
                return false
            }
        }

        var supportsHistoryImport: Bool {
            switch self {
            case .safari, .safariOld, .firefox, .chrome, .brave:
                return true
            case .passwordsCSV:
                return false
            }
        }

        var supportsAutomaticPasswordImport: Bool {
            switch self {
            case .chrome, .brave:
                return true
            case .safari, .safariOld, .firefox, .passwordsCSV:
                return false
            }
        }

        var passwordImporter: BrowserPasswordImporter? {
            switch self {
            case .chrome:
                return ChromiumPasswordImporter(browser: .chrome)
            case .brave:
                return ChromiumPasswordImporter(browser: .brave)
            case .firefox, .safari, .safariOld, .passwordsCSV:
                return nil
            }
        }

        var historyImporter: BrowserHistoryImporter? {
            switch self {
            case .safari, .safariOld:
                return SafariImporter()
            case .chrome:
                return ChromiumHistoryImporter(browser: .chrome)
            case .brave:
                return ChromiumHistoryImporter(browser: .brave)
            case .firefox:
                return FirefoxImporter()
            case .passwordsCSV:
                return nil
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
