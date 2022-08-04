//
//  AdvancedPreferencesJournalAndNotes.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI
import BeamCore

struct AdvancedPreferencesJournalAndNotes: View, BeamDocumentSource {
    public static var sourceId: String { "\(Self.self)"}

    @State private var dailyStatsExportDaysAgo: String = "0"
    @State private var showDebugSection = PreferencesManager.showDebugSection
    @State private var enableDailySummary = PreferencesManager.enableDailySummary
    @State private var createJournalOncePerWindow = PreferencesManager.createJournalOncePerWindow

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row(hasDivider: true) {
                Text("Notes:")
            } content: {
                ReindexNotesContents
                RebuildNotesContents
                ValidateNotesContents
                Create100RandomNotes
                Create100NormalNotes
                Create100JournalNotes
                Create10RandomNotes
                Create10NormalNotes
                Create10JournalNotes
            }
            Settings.Row(hasDivider: true) {
                Text("Create the journal views once")
            } content: {
                createJournalOncePerWindowView
                Settings.SubtitleLabel("(Needs restart)")
            }
            Settings.Row(hasDivider: true) {
                Text("Show Debug Section:")
            } content: {
                DebugSectionCheckbox
            }
            Settings.Row {
                Text("Daily Summary:")
            } content: {
                enableDailySummaryView
                HStack {
                    TextField("", text: $dailyStatsExportDaysAgo)
                        .frame(width: 50, height: 25, alignment: .center)
                    Text("Days ago")
                }
                ExportDailyUrlStats
                ExportDailyNoteStats
            }
        }
    }

    // MARK: - Notes
    private var ReindexNotesContents: some View {
        Button(action: { BeamNote.indexAllNotes(interactive: true) }, label: {
            Text("Reindex all notes' contents")
        })
    }

    private var RebuildNotesContents: some View {
        Button(action: { try? BeamNote.rebuildAllNotes(self, interactive: true) }, label: {
            Text("Rebuild all notes' contents")
        })
    }

    private var ValidateNotesContents: some View {
        Button(action: { try? BeamNote.validateAllNotes(interactive: true) }, label: {
            Text("Validate all notes' contents")
        })
    }

    private var Create100RandomNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 100, journalRatio: 0.2, futureRatio: 0.1)
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create100NormalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 100, journalRatio: 0.0, futureRatio: 0.0)
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create100JournalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 100, journalRatio: 1.0, futureRatio: 0.05)
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create10RandomNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 10, journalRatio: 0.2, futureRatio: 0.05)
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var Create10NormalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 10, journalRatio: 0.0, futureRatio: 0.0)
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var Create10JournalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 10, journalRatio: 1.0, futureRatio: 0.05)
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var DebugSectionCheckbox: some View {
        Toggle(isOn: $showDebugSection) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showDebugSection) {
                PreferencesManager.showDebugSection = $0
            }
    }

    private var createJournalOncePerWindowView: some View {
        Toggle(isOn: $createJournalOncePerWindow) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: createJournalOncePerWindow) {
                PreferencesManager.createJournalOncePerWindow = $0
            }
    }

    // MARK: - Daily Summary
    private var enableDailySummaryView: some View {
        return Toggle(isOn: $enableDailySummary) {
            Text("Enable")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: enableDailySummary) {
                PreferencesManager.enableDailySummary = $0
            }
    }

    private var ExportDailyNoteStats: some View {
        Button(action: {
            let panel = NSSavePanel()
            let daysAgo = Int(dailyStatsExportDaysAgo) ?? 0
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = DailyStatsExporter.noteStatsDefaultFileName(daysAgo: daysAgo)
            panel.showsTagField = false
            panel.begin { (result) in
                guard result == .OK, let url = panel.url else {
                    panel.close()
                    return
                }
                DailyStatsExporter.exportNoteStats(daysAgo: daysAgo, to: url)
            }
        }, label: {
            Text("Export note stats").frame(minWidth: 100)
        })
    }
    private var ExportDailyUrlStats: some View {
        Button(action: {
            let panel = NSSavePanel()
            let daysAgo = Int(dailyStatsExportDaysAgo) ?? 0
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = DailyStatsExporter.urlStatsDefaultFileName(daysAgo: daysAgo)
            panel.showsTagField = false
            panel.begin { (result) in
                guard result == .OK, let url = panel.url else {
                    panel.close()
                    return
                }
                DailyStatsExporter.exportUrlStats(daysAgo: daysAgo, to: url)
            }
        }, label: {
            Text("Export url stats").frame(minWidth: 100)
        })
    }
}

struct AdvancedPreferencesJournalAndNotes_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesJournalAndNotes()
    }
}
