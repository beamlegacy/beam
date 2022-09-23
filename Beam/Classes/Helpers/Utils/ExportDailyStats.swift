//
//  ExportDailyStats.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 03/06/2022.
//

import Foundation
import BeamCore

private struct DailyUrlStatsRow: CsvRow {

    let url: URL
    let title: String?
    let readingTime: Double
    let textAmount: Int
    let textSelections: Int
    let scrollRatioY: Float
    let navigationCountSinceLastSearch: Int
    let score: Float
    let isPinned: Bool
    let isSearchEngine: Bool
    let distinctVisitDayCount: Int?

    var columns: [String] { [
            url.urlStringWithoutScheme,
            title ?? "<???>",
            "\(readingTime)",
            "\(textAmount)",
            "\(textSelections)",
            "\(scrollRatioY)",
            "\(navigationCountSinceLastSearch)",
            "\(score)",
            "\(isPinned)",
            "\(isSearchEngine)",
            "\(url.isDomain)",
            "\(distinctVisitDayCount ?? 0)"
        ] }

    static var columnNames = [
        "url",
        "title",
        "readingTime",
        "textAmount",
        "textSelections",
        "scrollRatioY",
        "navigationCountSinceLastSearch",
        "score",
        "isPinned",
        "isSearchEngine",
        "isDomain",
        "rollingDistinctVisitDayCount"
    ]

    init(scoredUrl: ScoredURL, distinctVisitDayCount: Int?) {
        url = scoredUrl.url
        title = scoredUrl.title
        readingTime = scoredUrl.score.readingTimeToLastEvent
        textAmount = scoredUrl.score.textAmount
        textSelections = scoredUrl.score.textSelections
        scrollRatioY = scoredUrl.score.scrollRatioY
        navigationCountSinceLastSearch = scoredUrl.score.navigationCountSinceLastSearch ?? 0
        score = scoredUrl.score.score
        isPinned = scoredUrl.score.isPinned
        isSearchEngine = scoredUrl.url.isSearchEngineResultPage
        self.distinctVisitDayCount = distinctVisitDayCount
    }
}

private struct DailyNoteStatsRow: CsvRow {
    let title: String
    let addedBidiLinkToCount: Int
    let captureToCount: Int
    let visitCount: Int
    let firstToLastDeltaWordCount: Int
    let score: Float
    let created: Bool

    var columns: [String] { [
        title,
        "\(addedBidiLinkToCount)",
        "\(captureToCount)",
        "\(visitCount)",
        "\(firstToLastDeltaWordCount)",
        "\(score)",
        "\(created)"
        ]
    }

    static var columnNames = [
        "title",
        "addedBidiLinkToCount",
        "captureToCount",
        "visitCount",
        "firstToLastDeltaWordCount",
        "score",
        "created"
    ]

    init(scoredDocument: ScoredDocument) {
        title = scoredDocument.title
        addedBidiLinkToCount = scoredDocument.score.addedBidiLinkToCount
        captureToCount = scoredDocument.score.captureToCount
        visitCount = scoredDocument.score.visitCount
        firstToLastDeltaWordCount = scoredDocument.score.firstToLastDeltaWordCount
        score = scoredDocument.score.logScore
        created = scoredDocument.created
    }
}

class DailyStatsExporter {
    static func urlStatsDefaultFileName(offset0: Int, offset1: Int) -> String {
        let date0 = Calendar(identifier: .iso8601).date(byAdding: .day, value: -offset0, to: BeamDate.now)?.localDayString() ?? "0000-00-00"
        let date1 = Calendar(identifier: .iso8601).date(byAdding: .day, value: -offset1, to: BeamDate.now)?.localDayString() ?? "0000-00-00"

        return "beam_daily_url_stats-\(date0)-\(date1).csv"
    }
    static func noteStatsDefaultFileName(daysAgo: Int) -> String {
        let date = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString() ?? "0000-00-00"
        return "beam_daily_note_stats-\(date).csv"
    }

    static func exportUrlStats(offset0: Int, offset1: Int, to url: URL?) {
        guard let url = url else { return }
        let scoreStore = GRDBDailyUrlScoreStore()
        let scorer = DailyUrlScorer(store: scoreStore)
        let params = scorer.params
        let distinctVisitDayCounts = scoreStore.getUrlWithoutFragmentDistinctVisitDayCount(between: max(offset1 + params.maxRepeatTimeFrame, offset0), and: offset1)
        let urlStats = scorer.getHighScoredUrls(between: offset0, and: offset1, topN: 5000, filtered: false)
        let urlStatsRows: [DailyUrlStatsRow] = urlStats.map {
            DailyUrlStatsRow(scoredUrl: $0, distinctVisitDayCount: distinctVisitDayCounts[$0.url.absoluteString])
        }
        let writer = CsvRowsWriter(header: DailyUrlStatsRow.header, rows: urlStatsRows)
        do {
            try writer.overWrite(to: url)
        } catch {
            Logger.shared.logError("Unable to daily url stats to \(url)", category: .web)
        }
        print("Daily url stats saved to file \(url)")
    }
    static func exportNoteStats(daysAgo: Int, to url: URL?) {
        guard let url = url else { return }
        let scorer = NoteDailySummary(dailyScoreStore: GRDBDailyNoteScoreStore.shared)
        guard let noteStats = try? scorer.get(daysAgo: daysAgo, filtered: false) else { return }
        let noteStatsRows: [DailyNoteStatsRow] = noteStats.map { DailyNoteStatsRow(scoredDocument: $0) }
        let writer = CsvRowsWriter(header: DailyNoteStatsRow.header, rows: noteStatsRows)
        do {
            try writer.overWrite(to: url)
        } catch {
            Logger.shared.logError("Unable to daily note stats to \(url)", category: .web)
        }
        print("Daily note stats saved to file \(url)")
    }
}
