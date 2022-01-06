//
//  BrowserPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences
import Combine

let BrowserPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .browser, title: "Browser", imageName: "preferences-browser") {
    BrowserPreferencesView(viewModel: BrowserPreferencesViewModel())
}

class BrowserPreferencesViewModel: ObservableObject {
    @ObservedObject var onboardingManager: OnboardingManager = OnboardingManager(onlyImport: true)

    var scope = Set<AnyCancellable>()

    init() {
        onboardingManager.$needsToDisplayOnboard.sink { result in
            if !result {
                AppDelegate.main.closeOnboardingWindow()
            }
        }.store(in: &scope)
    }
}

struct BrowserPreferencesView: View {
    @ObservedObject var viewModel: BrowserPreferencesViewModel

    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section {
                Text("Default Browser:")
                    .frame(width: 250, alignment: .trailing)
            } content: {
                DefaultBrowserSection()
            }
            Preferences.Section(bottomDivider: true) {
                Text("Search Engine:")
            } content: {
                SearchEngineSection()
            }

            Preferences.Section(bottomDivider: true) {
                Text("Bookmarks & Settings:")
            } content: {
                BookmarksSection(viewModel: viewModel)
            }

            Preferences.Section(bottomDivider: true) {
                Text("Downloads:")
            } content: {
                DownloadSection()
            }

            Preferences.Section(bottomDivider: true) {
                Text("Tabs:")
            } content: {
                TabsSection()
            }

            Preferences.Section {
                Text("Clear Caches:")
            } content: {
                ClearCachesSection()
            }
        }
        .font(BeamFont.regular(size: 13).swiftUI)
        .foregroundColor(BeamColor.Generic.text.swiftUI)
    }
}

struct BrowserPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserPreferencesView(viewModel: BrowserPreferencesViewModel())
    }
}

struct DefaultBrowserSection: View {
    @State var isDefaultBrowser: Bool = BeamData.isDefaultBrowser

    var body: some View {
        Button {
            self.cancellable = Timer.publish(every: 0.1, on: .main, in: .default)
                .autoconnect()
                .sink { _ in
                    self.isDefaultBrowser = BeamData.isDefaultBrowser
                }
            BeamData.setAsMainBrowser()
        } label: {
            Text("Set Default...")
                .font(BeamFont.regular(size: 13).swiftUI)
        }.frame(width: 99, height: 20, alignment: .leading)
        .disabled(isDefaultBrowser)
    }

    @State var cancellable: Cancellable?
}

struct ClearCachesSection: View {

    var body: some View {
        Button {
            FaviconProvider.shared.clearCache()
            WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: { })
        } label: {
            Text("Clear All Web Caches")
                .font(BeamFont.regular(size: 13).swiftUI)
        }
    }
}

struct SearchEngineSection: View {
    @State private var selectedSearchEngine = PreferencesManager.selectedSearchEngine
    @State private var includeSearchEngineSuggestion =  PreferencesManager.includeSearchEngineSuggestion

    var body: some View {
        VStack(alignment: .leading) {
            Picker("", selection: $selectedSearchEngine) {
                ForEach(SearchEngineProvider.allCases) { engine in
                    Text(engine.name)
                }
            }.labelsHidden()
            .frame(width: 180, height: 20)
            .onReceive([self.selectedSearchEngine].publisher.first()) { value in
                PreferencesManager.selectedSearchEngine = value
            }
            Toggle(isOn: $includeSearchEngineSuggestion) {
                Text("Include search engine suggestions")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([includeSearchEngineSuggestion].publisher.first()) {
                    PreferencesManager.includeSearchEngineSuggestion = $0
                }
        }
    }
}

struct BookmarksSection: View {
    var viewModel: BrowserPreferencesViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                AppDelegate.main.showOnboardingWindow(model: viewModel.onboardingManager)
            } label: {
                Text("Import...")
                    .font(BeamFont.regular(size: 13).swiftUI)
            }.frame(width: 99, height: 20, alignment: .leading)
            Text("Import your bookmarks, passwords and history from other browsers")
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
    }
}

struct DownloadSection: View {
    @State private var selectedDownloadFolder = PreferencesManager.selectedDownloadFolder
    @State private var latestSelectedFolder: String?
    @State private var loaded = false
    @State private var pathToCustomDownloadHover = false

    var folders = [DownloadFolder.downloads, .custom]

    var body: some View {
        VStack(alignment: .leading) {
            Picker("", selection: $selectedDownloadFolder) {
                ForEach(folders) { folder in
                    HStack {
                        Image("preferences-folder-icon")
                        Text(folder.name)
                    }
                }
            }.labelsHidden()
            .frame(width: 180, height: 20)
            .onAppear(perform: {
                loaded = true
            })
            .onReceive([self.selectedDownloadFolder].publisher, perform: handleOnReceive)
            if self.selectedDownloadFolder == DownloadFolder.custom.rawValue {
                pathToCustomDownloadFolderButton
            }
        }
    }

    private func handleOnReceive(value: Int) {
        guard loaded else { return }
        guard let folder = DownloadFolder(rawValue: value) else { return }
        if folder != .downloads {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.directoryURL = DownloadFolder(rawValue: value)?.rawUrl
            panel.prompt = "Select"
            panel.runModal()

            let choosedFolder = panel.url

            guard let bookmark = try? choosedFolder?.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else {
                return
            }
            PreferencesManager.customDownloadFolder = bookmark
            PreferencesManager.selectedDownloadFolder = value
            self.loaded = false
            self.selectedDownloadFolder = value
            self.latestSelectedFolder = choosedFolder?.url?.path
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                self.loaded = true
            }
        } else {
            PreferencesManager.selectedDownloadFolder = value
            PreferencesManager.customDownloadFolder = nil
        }
    }

    @ViewBuilder private var pathToCustomDownloadFolderButton: some View {
        ButtonLabel(pathToCustomDownload, customStyle: ButtonLabelStyle(font: BeamFont.regular(size: 11).swiftUI, foregroundColor: BeamColor.Corduroy.swiftUI, activeForegroundColor: BeamColor.Niobium.swiftUI, activeBackgroundColor: BeamColor.AlphaGray.swiftUI)) {
            guard let folder = DownloadFolder.custom.rawUrl else { return }
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
        .onHover(perform: { hovering in
            self.pathToCustomDownloadHover = hovering
        })
        .foregroundColor(BeamColor.Corduroy.swiftUI)
        .lineLimit(nil)
        .multilineTextAlignment(.leading)
    }

    private var pathToCustomDownload: String {
        if let selection = self.latestSelectedFolder {
            return selection
        } else if self.selectedDownloadFolder == DownloadFolder.custom.rawValue {
            return DownloadFolder.custom.rawUrl?.path ?? ""
        }
        return ""
    }
}

struct TabsSection: View {
    @State private var cmdClickOpenTab = PreferencesManager.cmdClickOpenTab
    @State private var newTabWindowMakeActive = PreferencesManager.newTabWindowMakeActive
    @State private var cmdNumberSwitchTabs = PreferencesManager.cmdNumberSwitchTabs
    @State private var showWebsiteIconTab = PreferencesManager.showWebsiteIconTab
    @State private var restoreLastBeamSession = PreferencesManager.restoreLastBeamSession

    var body: some View {
        Toggle(isOn: $cmdClickOpenTab) {
            Text("⌘-click opens a link in a new tab")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([cmdClickOpenTab].publisher.first()) {
                PreferencesManager.cmdClickOpenTab = $0
            }
//        Toggle(isOn: $newTabWindowMakeActive) {
//            Text("When a new tab or window opens, make it active")
//        }.toggleStyle(CheckboxToggleStyle())
//            .font(BeamFont.regular(size: 13).swiftUI)
//            .foregroundColor(BeamColor.Generic.text.swiftUI)

        Toggle(isOn: $cmdNumberSwitchTabs) {
            Text("Use ⌘1 to ⌘9 to switch tabs")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([cmdNumberSwitchTabs].publisher.first()) {
                PreferencesManager.cmdNumberSwitchTabs = $0
            }
//        Toggle(isOn: $showWebsiteIconTab) {
//            Text("Show website icons in tabs")
//        }.toggleStyle(CheckboxToggleStyle())
//            .font(BeamFont.regular(size: 13).swiftUI)
//            .foregroundColor(BeamColor.Generic.text.swiftUI)

        Toggle(isOn: $restoreLastBeamSession) {
            Text("Restore all tabs from last session")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([restoreLastBeamSession].publisher.first()) {
                PreferencesManager.restoreLastBeamSession = $0
            }
    }
}
