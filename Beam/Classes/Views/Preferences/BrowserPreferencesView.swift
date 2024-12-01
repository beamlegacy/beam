//
//  BrowserPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Combine
import BeamCore

final class BrowserPreferencesViewModel: ObservableObject {
    var accountData: BeamData
    @ObservedObject var onboardingManager: OnboardingManager = OnboardingManager(onlyImport: true)

    init(accountData: BeamData) {
        self.accountData = accountData
    }
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
        var rows = [searchEngineRow, importBrowserDataRow, historyRow, downloadsRow, tabsRow, soundsRow, videoCallsRow, linksRow, clearCachesRow]

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

    private var historyRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Remove history items:")
        } content: {
            HistorySection(viewModel: viewModel)
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

    private var videoCallsRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Video Calls:")
        } content: {
            VideoCallsSection()
        }
    }

    private var linksRow: Settings.Row {
        Settings.Row(hasDivider: true) {
            Text("Links:")
        } content: {
            CopyLinksSection()
        }
    }

    private var clearCachesRow: Settings.Row {
        Settings.Row {
            Text("Clear Caches:")
        } content: {
            ClearCachesSection(viewModel: viewModel)
        }
    }
}

struct BrowserPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserPreferencesView(viewModel: BrowserPreferencesViewModel(accountData: BeamData()))
    }
}

private struct DefaultBrowserSection: View {
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

private struct ClearCachesSection: View {
    var viewModel: BrowserPreferencesViewModel
    var body: some View {
        Button {
            WebContentDeletionManager(accountData: viewModel.accountData).clearWebCaches(.all)
        } label: {
            Text("Clear All Web Caches")
                .accessibilityIdentifier("clear-cache-button")
                .font(BeamFont.regular(size: 13).swiftUI)
        }
    }
}

private struct SearchEngineSection: View {
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

private struct BookmarksSection: View {
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

private struct HistorySection: View {
    var viewModel: BrowserPreferencesViewModel
    @State private var clearHistoryPanel = false
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                clearHistoryPanel = true
            } label: {
                Text("Clear History...")
                    .font(BeamFont.regular(size: 13).swiftUI)
            }
            .frame(minWidth: 120, alignment: .leading)
            .frame(height: 20)
        }
        .sheet(isPresented: $clearHistoryPanel) {
            ClearHistoryModalView(viewModel: viewModel)
        }
    }
}

struct ClearHistoryModalView: View {
    var viewModel: BrowserPreferencesViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedHistoryInterval = WebContentDeletionManager.HistoryInterval.hour
    var body: some View {
        VStack {
            HStack(spacing: BeamSpacing._200) {
                AppIcon()
                    .scaledToFit()
                    .frame(width: 64, height: 64, alignment: .top)
                VStack(alignment: .leading, spacing: BeamSpacing._100) {
                    Text("Clearing history will remove related cookies \nand other website data.")
                        .font(BeamFont.semibold(size: 13).swiftUI)
                        .lineLimit(nil)
                        .fixedSize()
                    HStack(spacing: 0) {
                        Text("Clear:")
                            .font(BeamFont.regular(size: 13).swiftUI)
                        Picker("", selection: $selectedHistoryInterval) {
                            ForEach(WebContentDeletionManager.HistoryInterval.allCases, id: \.self) { interval in
                                Text(interval.longLocalizedDescription)
                            }
                        }
                        .fixedSize()
                        .accessibilityIdentifier("history-interval-selector")
                    }
                }
            }
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("cancel")
                Button("Clear History") {
                    clear()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("clear-history")
            }
        }
        .padding(BeamSpacing._200)
        .frame(idealWidth: 420)
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }

    private func clear() {
        let manager = WebContentDeletionManager(accountData: viewModel.accountData)
        do {
            try manager.clearHistory(selectedHistoryInterval)
        } catch {
            Logger.shared.logError("Error clearing history \(error)", category: .general)
        }
        manager.clearWebCaches(selectedHistoryInterval)
        dismiss()
    }
}

private struct DownloadSection: View {
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

private struct TabsSection: View {
    @State private var cmdClickOpenTab = PreferencesManager.cmdClickOpenTab
//    @State private var newTabWindowMakeActive = PreferencesManager.newTabWindowMakeActive
    @State private var cmdNumberSwitchTabs = PreferencesManager.cmdNumberSwitchTabs
//    @State private var showWebsiteIconTab = PreferencesManager.showWebsiteIconTab
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

private struct SoundsSection: View {
    @State private var isCollectSoundsEnabled = PreferencesManager.isCollectSoundsEnabled

    var body: some View {
        Toggle(isOn: $isCollectSoundsEnabled) {
            Text("Enable Capture sounds")
        }
        .accessibilityIdentifier("capture-sounds-checkbox")
        .toggleStyle(CheckboxToggleStyle())
        .font(BeamFont.regular(size: 13).swiftUI)
        .foregroundColor(BeamColor.Generic.text.swiftUI)
        .onChange(of: isCollectSoundsEnabled) {
            PreferencesManager.isCollectSoundsEnabled = $0
        }
    }
}

struct VideoCallsSection: View {
    @State private var videoCallsAlwaysInSideWindow = PreferencesManager.videoCallsAlwaysInSideWindow

    var body: some View {
        Toggle(isOn: $videoCallsAlwaysInSideWindow) {
            Text("Always open in side window")
        }
        .accessibilityIdentifier("videoCalls-always-in-side-window-checkbox")
        .toggleStyle(CheckboxToggleStyle())
        .font(BeamFont.regular(size: 13).swiftUI)
        .foregroundColor(BeamColor.Generic.text.swiftUI)
        .onChange(of: videoCallsAlwaysInSideWindow) {
            PreferencesManager.videoCallsAlwaysInSideWindow = $0
        }
    }
}

private struct CopyLinksSection: View {
    @State private var isLinkTextFragmentEnabled = PreferencesManager.isLinkTextFragmentEnabled

    var body: some View {
        Toggle(isOn: $isLinkTextFragmentEnabled) {
            Text("Enable Link Text Fragment on Copy")
        }
        .accessibilityIdentifier("link-fragment-checkbox")
        .toggleStyle(CheckboxToggleStyle())
        .font(BeamFont.regular(size: 13).swiftUI)
        .foregroundColor(BeamColor.Generic.text.swiftUI)
        .onChange(of: isLinkTextFragmentEnabled) {
            PreferencesManager.isLinkTextFragmentEnabled = $0
        }
    }
}

