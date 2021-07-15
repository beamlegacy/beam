//
//  BrowserPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences

let BrowserPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .browser, title: "Browser", imageName: "preferences-browser") {
    BrowserPreferencesView()
}

struct BrowserPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section {
                Text("Default Browser:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                DefaultBrowserSection()
            }
            Preferences.Section(bottomDivider: true) {
                Text("Search Engine:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                SearchEngineSection()
            }

            Preferences.Section(bottomDivider: true) {
                Text("Bookmarks & Settings:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                BookmarksSection()
            }

            Preferences.Section(bottomDivider: true) {
                Text("Downloads:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                DownloadSection()
            }

            Preferences.Section {
                Text("Tabs:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                TabsSection()
            }
        }
    }
}

struct BrowserPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserPreferencesView()
    }
}

struct DefaultBrowserSection: View {
    @State var isDefaultBrowser: Bool = PreferencesManager.isDefaultBrowser

    var body: some View {
        Button {
            PreferencesManager.isDefaultBrowser.toggle()
            isDefaultBrowser.toggle()
        } label: {
            Text("Set Default...")
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
        }.frame(width: 99, height: 20, alignment: .leading)
        .disabled(isDefaultBrowser)
    }
}

struct SearchEngineSection: View {
    @State private var selectedSearchEngine = PreferencesManager.selectedSearchEngine

    var body: some View {
        VStack(alignment: .leading) {
            Picker("", selection: $selectedSearchEngine) {
                ForEach(SearchEnginesPreferences.allCases) { engine in
                    Text(engine.name)
                }
            }.labelsHidden()
            .frame(width: 180, height: 20)
            .onReceive([self.selectedSearchEngine].publisher.first()) { value in
                PreferencesManager.selectedSearchEngine = value
            }
            Checkbox(checkState: PreferencesManager.includeSearchEngineSuggestion, text: "Include search engine suggestions", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                PreferencesManager.includeSearchEngineSuggestion = activated
            }
        }
    }
}

struct BookmarksSection: View {
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.canDownloadUbiquitousContents = false
                openPanel.allowsMultipleSelection = true
                openPanel.allowedFileTypes = ["csv", "txt"]
                openPanel.title = "Import your bookmarks, passwords and history from other browsers"
                openPanel.begin { _ in
                    // TODO: Implement the import
                }
            } label: {
                Text("Import...")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
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

    var body: some View {
        VStack(alignment: .leading) {
            Picker("", selection: $selectedDownloadFolder) {
                ForEach(DownloadFolder.allCases) { folder in
                    HStack {
                        Image("preferences-folder-icon")
                        Text(folder.name)
                    }
                }
            }.labelsHidden()
            .frame(width: 180, height: 20)
            .onReceive([self.selectedDownloadFolder].publisher.first()) { value in
                PreferencesManager.selectedDownloadFolder = value
                if PreferencesManager.defaultDownloadFolder == DownloadFolder.custom.rawValue {
                    let openPanel = NSOpenPanel()
                    openPanel.canChooseFiles = false
                    openPanel.canChooseDirectories = true
                    openPanel.canDownloadUbiquitousContents = false
                    openPanel.allowsMultipleSelection = false
                    openPanel.begin { _ in
                        // TODO: Implement the download folder setting
                    }
                }
            }
            Checkbox(checkState: PreferencesManager.openSafeFileAfterDownload, text: "Open “safe” files after downloading", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                PreferencesManager.openSafeFileAfterDownload = activated
            }
        }
    }
}

struct TabsSection: View {
    var body: some View {
        Checkbox(checkState: PreferencesManager.cmdClickOpenTab, text: "⌘-click opens a link in a new tab", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.cmdClickOpenTab = activated
        }
        Checkbox(checkState: PreferencesManager.newTabWindowMakeActive, text: "When a new tab or window opens, make it active", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.newTabWindowMakeActive = activated
        }
        Checkbox(checkState: PreferencesManager.cmdNumberSwitchTabs, text: "Use ⌘1 to ⌘9 to switch tabs", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.cmdNumberSwitchTabs = activated
        }
        Checkbox(checkState: PreferencesManager.showWebsiteIconTab, text: "Show website icons in tabs", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.showWebsiteIconTab = activated
        }
        Checkbox(checkState: PreferencesManager.restoreLastBeamSession, text: "Restore all tabs from last session when opening Beam", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.restoreLastBeamSession = activated
        }
    }
}
