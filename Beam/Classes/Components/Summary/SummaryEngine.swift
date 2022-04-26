//
//  SummaryEngine.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/04/2022.
//

import Foundation
import BeamCore

class SummaryEngine {
    static let shared = SummaryEngine()
    static let summaryDecoratedValue = AttributeDecoratedValueAttributedString(attributes: [.foregroundColor: BeamColor.LightStoneGray.nsColor],
                                                                               editable: false)

    static func getContinueToSummary() -> BeamElement? {
        var hasNotes: Bool = false
        let element = BeamElement()
        element.kind = .dailySummary
        element.text = BeamText("Continue working on ", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])

        if let notesToContinue = try? NoteDailySummary().get(), !notesToContinue.isEmpty {
            hasNotes = true
            var noteToContinueText: [BeamText] = []
            for noteToContinue in notesToContinue {
                noteToContinueText.append(BeamText(text: noteToContinue.title, attributes: [.internalLink(noteToContinue.noteId)]))
            }
            element.text.append(joined(sources: noteToContinueText, with: ", "))
        }

        let urlScores = GRDBDailyUrlScoreStore().getHighScoredUrlIds(daysAgo: 1, topN: 2)
        guard !urlScores.isEmpty else { return hasNotes ? element : nil }
        var siteToContinueText: [BeamText] = []
        for urlScore in urlScores {
            guard let link = LinkStore.linkFor(urlScore.urlId), let title = link.title else { continue }
            siteToContinueText.append(BeamText(text: title, attributes: [.link(link.url)]))
        }
        element.text.append(summarySeparator(" and "))
        element.text.append(joined(sources: siteToContinueText, with: ", "))

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
            if let updatedNoteText = buildUpdatedNoteText(updatedNotes, isBeginningOfSentence: !hasCreatedNotes) {
                hasUpdatedNotes = true
                if !hasCreatedNotes {
                    element = BeamElement()
                    element?.kind = .dailySummary
                } else {
                    element?.text.append(summarySeparator(", "))
                }
                element?.text.append(updatedNoteText)
            }
        }

        let urlScores = GRDBDailyUrlScoreStore().getHighScoredUrlIds(daysAgo: 0, topN: 2)
        guard !urlScores.isEmpty,
              let spentTimeOnSiteText = buildSpentTimeOnSiteText(urlScores, isBeginningOfSentence: !(hasCreatedNotes || hasUpdatedNotes)) else { return element }
        if !hasCreatedNotes && !hasUpdatedNotes {
            element = BeamElement()
            element?.kind = .dailySummary
        } else {
            element?.text.append(summarySeparator(" and "))
        }
        element?.text.append(spentTimeOnSiteText)

        return element
    }

    private static func buildCreatedNoteText(_ createdNotes: [ScoredDocument]) -> BeamText? {
        guard !createdNotes.isEmpty else { return nil }
        var createdNoteBaseText = BeamText("Created ", attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])
        var createdNoteText: [BeamText] = []
        for createdNote in createdNotes {
            createdNoteText.append(BeamText(text: createdNote.title, attributes: [.internalLink(createdNote.noteId)]))
        }

        guard !createdNoteText.isEmpty else { return nil }
        createdNoteBaseText.append(joined(sources: createdNoteText, with: " and "))

        return createdNoteBaseText
    }

    private static func buildUpdatedNoteText(_ updatedNotes: [ScoredDocument], isBeginningOfSentence: Bool) -> BeamText? {
        guard !updatedNotes.isEmpty else { return nil }
        let baseText = "worked on "
        var updatedNoteBaseText = BeamText(isBeginningOfSentence ? baseText.capitalizeFirstChar() : baseText, attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])
        var updatedNoteText: [BeamText] = []
        for updatedNote in updatedNotes {
            updatedNoteText.append(BeamText(text: updatedNote.title, attributes: [.internalLink(updatedNote.noteId)]))
        }

        guard !updatedNoteText.isEmpty else { return nil }
        updatedNoteBaseText.append(joined(sources: updatedNoteText, with: " and "))

        return updatedNoteBaseText
    }

    private static func buildSpentTimeOnSiteText(_ urlScores: [DailyURLScore], isBeginningOfSentence: Bool) -> BeamText? {
        guard !urlScores.isEmpty else { return nil }
        let baseText = "spent time on "
        var spentTimeOnSiteBaseText = BeamText(isBeginningOfSentence ? baseText.capitalizeFirstChar() : baseText, attributes: [BeamText.Attribute.decorated(summaryDecoratedValue)])
        var spentTimeOnSiteText: [BeamText] = []
        for urlScore in urlScores {
            guard let link = LinkStore.linkFor(urlScore.urlId), let title = link.title else { continue }
            spentTimeOnSiteText.append(BeamText(text: title, attributes: [.link(link.url)]))
        }

        guard !spentTimeOnSiteText.isEmpty else { return nil }
        spentTimeOnSiteBaseText.append(joined(sources: spentTimeOnSiteText, with: " and "))

        return spentTimeOnSiteBaseText
    }

    private static func joined(sources: [BeamText], with separator: String) -> BeamText {
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
