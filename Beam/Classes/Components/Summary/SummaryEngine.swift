//
//  SummaryEngine.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/04/2022.
//

import Foundation
import BeamCore

class SummaryEngine {
    static private let maxUrlDisplayLength: Int = 50

    static let shared = SummaryEngine()
    static let summaryDecoratedValue = AttributeDecoratedValueAttributedString(attributes: [.foregroundColor: BeamColor.LightStoneGray.nsColor],
                                                                               editable: false)

    static func getContinueToSummary() -> BeamElement? {
        var hasNotes: Bool = false
        let element = BeamElement()
        element.kind = .dailySummary
        element.text = BeamText("Continue on ", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])

        if let notesToContinue = try? NoteDailySummary().get(), !notesToContinue.isEmpty {
            hasNotes = true
            var noteToContinueText: [BeamText] = []
            for noteToContinue in notesToContinue {
                noteToContinueText.append(BeamText(text: noteToContinue.title, attributes: [.internalLink(noteToContinue.noteId)]))
            }
            if let joinedText = joined(sources: noteToContinueText, with: ", ") {
                element.text.append(joinedText)
            }
        }

        let urlScores = DailyUrlScorer(store: GRDBDailyUrlScoreStore()).getHighScoredUrls(between: 1, and: 1, topN: 2)
        guard !urlScores.isEmpty else { return hasNotes ? element : nil }
        var siteToContinueText: [BeamText] = []
        for urlScore in urlScores {
            siteToContinueText.append(BeamText(text: urlScore.displayText(maxUrlLength: maxUrlDisplayLength), attributes: [.link(urlScore.url.absoluteString)]))
        }
        guard let joinedText = joined(sources: siteToContinueText, with: ", ") else { return element }
        if hasNotes {
            element.text.append(summarySeparator(" and "))
        }
        element.text.append(joinedText)
        return element
    }

    static func getDailySummary() -> BeamElement? {
        var element: BeamElement?
        var hasCreatedNotes: Bool = false
        var hasUpdatedNotes: Bool = false

        if let dailyNotes = try? NoteDailySummary().get(daysAgo: 0) {
            var createdNotes: [ScoredDocument] = []
            var updatedNotes: [ScoredDocument] = []
            for dailyNote in dailyNotes {
                if dailyNote.created {
                    createdNotes.append(dailyNote)
                } else {
                    updatedNotes.append(dailyNote)
                }
            }

            if let createdNoteText = buildCreatedNoteText(createdNotes) {
                hasCreatedNotes = true
                element = BeamElement()
                element?.kind = .dailySummary
                element?.text = createdNoteText
            }

            if let updatedNoteText = buildUpdatedNoteText(updatedNotes) {
                hasUpdatedNotes = true
                if !hasCreatedNotes {
                    element = BeamElement()
                    element?.kind = .dailySummary
                }
                element?.text.append(BeamText(hasCreatedNotes ? " Worked on " : "Worked on ", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)]))
                element?.text.append(updatedNoteText)
            }
        }

        let urlScores = DailyUrlScorer(store: GRDBDailyUrlScoreStore()).getHighScoredUrls(between: 0, and: 0, topN: 2)
        guard !urlScores.isEmpty,
              let spentTimeOnSiteText = buildSpentTimeOnSiteText(urlScores) else { return element }
        if !hasUpdatedNotes {
            if !hasCreatedNotes {
                element = BeamElement()
                element?.kind = .dailySummary
            }
            element?.text.append(BeamText(hasCreatedNotes ? " Worked on " : "Worked on ", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)]))
        } else {
            element?.text.append(summarySeparator(" and "))
        }
        element?.text.append(spentTimeOnSiteText)

        return element
    }

    private static func buildCreatedNoteText(_ createdNotes: [ScoredDocument]) -> BeamText? {
        guard !createdNotes.isEmpty else { return nil }
        var createdNoteBaseText = BeamText("Started ", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])
        var createdNoteText: [BeamText] = []
        for createdNote in createdNotes {
            createdNoteText.append(BeamText(text: createdNote.title, attributes: [.internalLink(createdNote.noteId)]))
        }

        guard let joinedText = joined(sources: createdNoteText, with: ", ") else { return nil }
        createdNoteBaseText.append(joinedText)
        createdNoteBaseText.append(BeamText(".", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)]))
        return createdNoteBaseText
    }

    private static func buildUpdatedNoteText(_ updatedNotes: [ScoredDocument]) -> BeamText? {
        guard !updatedNotes.isEmpty else { return nil }
        var updatedNoteText: [BeamText] = []
        for updatedNote in updatedNotes {
            updatedNoteText.append(BeamText(text: updatedNote.title, attributes: [.internalLink(updatedNote.noteId)]))
        }

        return joined(sources: updatedNoteText, with: ", ")
    }

    private static func buildSpentTimeOnSiteText(_ urlScores: [ScoredURL]) -> BeamText? {
        guard !urlScores.isEmpty else { return nil }
        var spentTimeOnSiteText: [BeamText] = []
        for urlScore in urlScores {
            spentTimeOnSiteText.append(BeamText(text: urlScore.displayText(maxUrlLength: maxUrlDisplayLength), attributes: [.link(urlScore.url.absoluteString)]))
        }

        return joined(sources: spentTimeOnSiteText, with: ", ")
    }

    private static func joined(sources: [BeamText], with separator: String) -> BeamText? {
        guard !sources.isEmpty else { return nil }

        var sourceText = sources[0]

        guard sources.count > 1 else { return sourceText }
        sourceText.append(BeamText(separator, attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)]))
        sourceText.append(sources[1])

        return sourceText
    }

    private static func summarySeparator(_ text: String) -> BeamText {
        BeamText(text, attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])
    }

}
