//
//  BrowserPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Combine

class BrowserPreferencesViewModel: ObservableObject {
    @ObservedObject var onboardingManager: OnboardingManager = OnboardingManager(onlyImport: true)

    var scope = Set<AnyCancellable>()
}

struct BrowserPreferencesView: View {
    @ObservedObject var viewModel: BrowserPreferencesViewModel

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            ForEach(0..<getSettingsRows().count, id: \.self) { index in
                getSettingsRows()[index]
            }
        }
    }

    private func getSettingsRows() -> [Settings.Row] {
        var rows = [searchEngineRow, importBrowserDataRow, downloadsRow, tabsRow, soundsRow, clearCachesRow]

        if !BeamData.isDefaultBrowser {
            rows.insert(defaultBrowserRow, at: 0)
        }
        return rows
    }

    private var defaultBrowserRow: Settings.Row {
        Settings.Row {
            Text("Default Browser:")
        } content: {
            DefaultBrowserSection()
        }
    }

    private var searchEngineRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Search Engine:")
        } content: {
            SearchEngineSection()
        }
    }

    private var importBrowserDataRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Import Browser Data:")
        } content: {
            BookmarksSection(viewModel: viewModel)
        }
    }

    private var downloadsRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Downloads:")
        } content: {
            DownloadSection()
        }
    }

    private var tabsRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Tabs:")
        } content: {
            TabsSection()
        }
    }

    private var soundsRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Sounds:")
        } content: {
            SoundsSection()
        }
    }

    private var clearCachesRow: Settings.Row {
        Settings.Row {
            Text("Clear Caches:")
        } content: {
            ClearCachesSection()
        }
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
                .accessibilityIdentifier("clear-cache-button")
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
            }.accessibilityIdentifier("search-engine-selector")
            .labelsHidden()
            .frame(width: 180, height: 20)
            .onChange(of: selectedSearchEngine, perform: {
                PreferencesManager.selectedSearchEngine = $0
            })
            Toggle(isOn: $includeSearchEngineSuggestion) {
                Text("Include search engine suggestions")
            }.accessibilityIdentifier("search-engine-suggestion")
            .toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: includeSearchEngineSuggestion, perform: {
                    PreferencesManager.includeSearchEngineSuggestion = $0
                })
        }
    }
}

struct BookmarksSection: View {
    var viewModel: BrowserPreferencesViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                viewModel.onboardingManager.presentOnboardingWindow()
            } label: {
                Text("Import...")
                    .font(BeamFont.regular(size: 13).swiftUI)
            }.frame(width: 99, height: 20, alignment: .leading)
            Settings.SubtitleLabel("Import your passwords and history from other browsers.")
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
            .onChange(of: selectedDownloadFolder, perform: {
                handleOnReceive(value: $0)
            })
            if self.selectedDownloadFolder == DownloadFolder.custom.rawValue && PreferencesManager.customDownloadFolder != nil {
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

            if panel.runModal() == .cancel {
                self.selectedDownloadFolder = PreferencesManager.selectedDownloadFolder
                return
            }

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
    @State private var enableTabGrouping = PreferencesManager.enableTabGrouping

    var body: some View {
        Group {
            Toggle(isOn: $enableTabGrouping) {
                Text("Group tabs automatically")
            }
            .accessibilityIdentifier("group-tabs-checkbox")
            .toggleStyle(CheckboxToggleStyle())
            .onChange(of: enableTabGrouping, perform: {
                PreferencesManager.enableTabGrouping = $0
            })

            Toggle(isOn: $cmdClickOpenTab) {
                Text("⌘-click opens a link in a new tab")
            }
            .accessibilityIdentifier("cmd-click-checkbox")
            .toggleStyle(CheckboxToggleStyle())
            .onChange(of: cmdClickOpenTab, perform: {
                PreferencesManager.cmdClickOpenTab = $0
            })

    //        Toggle(isOn: $newTabWindowMakeActive) {
    //            Text("When a new tab or window opens, make it active")
    //        }.toggleStyle(CheckboxToggleStyle())

            Toggle(isOn: $cmdNumberSwitchTabs) {
                Text("Use ⌘1 to ⌘9 to switch tabs")
            }
            .accessibilityIdentifier("switch-tabs-checkbox")
            .toggleStyle(CheckboxToggleStyle())
            .onChange(of: cmdNumberSwitchTabs, perform: {
                PreferencesManager.cmdNumberSwitchTabs = $0
            })

    //        Toggle(isOn: $showWebsiteIconTab) {
    //            Text("Show website icons in tabs")
    //        }.toggleStyle(CheckboxToggleStyle())
        }
        .font(BeamFont.regular(size: 13).swiftUI)
        .foregroundColor(BeamColor.Generic.text.swiftUI)
    }
}

struct SoundsSection: View {
    @State private var isCollectSoundsEnabled = PreferencesManager.isCollectSoundsEnabled

    var body: some View {
        Toggle(isOn: $isCollectSoundsEnabled) {
            Text("Enable Capture sounds")
        }.accessibilityIdentifier("capture-sounds-checkbox")
            .toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isCollectSoundsEnabled, perform: {
                PreferencesManager.isCollectSoundsEnabled = $0
            })
    }
}
