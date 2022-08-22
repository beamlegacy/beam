//
//  DailyUrlScore.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 28/03/2022.
//

import Foundation

public struct DailySummaryUrlParams {
    public let minReadingTime: Double
    public let minTextAmount: Int
    public let maxRepeatTimeFrame: Int //number of observation days
    public let maxRepeat: Int
}

public class DailyURLScore: Codable, UrlScoreProtocol {
    public var id = UUID()
    public var createdAt = BeamDate.now
    public var updatedAt = BeamDate.now
    public var urlId: UUID
    public var localDay: String
    public var visitCount: Int = 0
    public var readingTimeToLastEvent: CFTimeInterval = 0
    public var textSelections: Int = 0
    public var scrollRatioX: Float = 0
    public var scrollRatioY: Float = 0
    public var textAmount: Int = 0
    public var area: Float = 0
    public var isPinned: Bool = false //true if isPinned at least once during period
    public var navigationCountSinceLastSearch: Int?

    public init(urlId: UUID, localDay: String) {
        self.urlId = urlId
        self.localDay = localDay
    }

    public var score: Float {
        return min(scrollRatioY, 1) //temporary before scroll ratio fix
            + log(1 + Float(readingTimeToLastEvent))
            + log(1 + Float(textAmount))
            + log(1 + Float(textSelections))
            + log(1 + Float(navigationCountSinceLastSearch ?? 0))
    }
}

public protocol DailyUrlScoreStoreProtocol {
    func apply(to urlId: UUID, changes: @escaping (DailyURLScore) -> Void)
    func getScores(daysAgo: Int) -> [UUID: DailyURLScore]
    func getAggregatedScores(between offset0: Int, and offset1: Int) -> [UUID: AggregatedURLScore]
    func getDailyRepeatingUrlsWithoutFragment(between offset0: Int, and offset1: Int, minRepeat: Int) -> Set<String>
    func getUrlWithoutFragmentDistinctVisitDayCount(between offset0: Int, and offset1: Int) -> [String: Int]
}

public struct AggregatedURLScore: Decodable {
    public var urlId: UUID?
    public var visitCount: Int = 0
    public var readingTimeToLastEvent: CFTimeInterval = 0
    public var textSelections: Int = 0
    public var scrollRatioX: Float = 0
    public var scrollRatioY: Float = 0
    public var textAmount: Int = 0
    public var area: Float = 0
    public var isPinned: Bool = false //true if isPinned at least once during period
    public var navigationCountSinceLastSearch: Int?

    public var score: Float {
        return scrollRatioY
            + log(1 + Float(readingTimeToLastEvent))
            + log(1 + Float(textAmount))
            + log(1 + Float(textSelections))
            + log(1 + Float(navigationCountSinceLastSearch ?? 0))
    }
    func isSummaryEligible(minReadingTime: Double, minTextAmount: Int) -> Bool {
        !(isPinned
            || readingTimeToLastEvent < minReadingTime
            || textAmount < minTextAmount
            || textSelections > 0 // pns'd page are to be displayed in a dedicated section
        )
    }
    public func merge(other: AggregatedURLScore, keepUrlId: Bool = false) -> AggregatedURLScore {
        return AggregatedURLScore(
            urlId: keepUrlId ? urlId : nil,
            visitCount: other.visitCount + self.visitCount,
            readingTimeToLastEvent: other.readingTimeToLastEvent + self.readingTimeToLastEvent,
            textSelections: other.textSelections + self.textSelections,
            scrollRatioX: max(other.scrollRatioX, self.scrollRatioX),
            scrollRatioY: max(other.scrollRatioY, self.scrollRatioY),
            textAmount: max(other.textAmount, self.textAmount),
            area: max(other.area, self.area),
            isPinned: other.isPinned || self.isPinned,
            navigationCountSinceLastSearch: nilMin(navigationCountSinceLastSearch, self.navigationCountSinceLastSearch)
        )
    }

}

public struct ScoredURL {
    public let url: URL
    public var title: String?
    public let score: AggregatedURLScore

    public func displayText(maxUrlLength: Int) -> String {
        guard let title = title, !title.isEmpty else {
            return url.shortString(maxLength: maxUrlLength)
        }
        return title
    }
}

private extension URL {
    func replaceScheme(with scheme: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = scheme
        return components.url
    }
}

public class UrlGroups {

    let groups: [URL: [UUID]]
    init(groups: [URL: [UUID]]) {
        self.groups = groups
    }
    init(links: [UUID: Link]) {
        let ungroupedLinks = links.compactMap { (urlId, link) -> (URL, [UUID])? in
            guard let url = URL(string: link.url) else { return nil }
            return (url, [urlId])
        }
        self.groups = Dictionary(uniqueKeysWithValues: ungroupedLinks)
    }

    public func regroup(transform: (URL) -> URL?) -> UrlGroups {
        var regrouped = [URL: [UUID]]()
        for (url, oldGroup) in groups {
            guard let transformed = transform(url) else { continue }
            if var newGroup = regrouped[transformed] {
                newGroup.append(contentsOf: oldGroup)
                regrouped[transformed] = newGroup
            } else {
                regrouped[transformed] = oldGroup
            }
        }
        return UrlGroups(groups: regrouped)
    }

    public var groupHTTPSchemes: UrlGroups {
        var schemeGrouped = [URL: [UUID]]()
        for (url, urlIds) in groups {
            switch url.scheme {
            case "https":
                if let httpUrl = url.replaceScheme(with: "http"),
                   let httpGroup = schemeGrouped[httpUrl] {
                    schemeGrouped[url] = httpGroup + urlIds
                    schemeGrouped[httpUrl] = nil
                } else {
                    schemeGrouped[url] = urlIds
                }
            case "http":
                if let httpsUrl = url.replaceScheme(with: "https"),
                   let httpsGroup = schemeGrouped[httpsUrl] {
                    schemeGrouped[httpsUrl] = httpsGroup + urlIds
                } else {
                    schemeGrouped[url] = urlIds
                }
            default:
                schemeGrouped[url] = urlIds
            }
        }
        return UrlGroups(groups: schemeGrouped)
    }
    func aggregate(scores: [UUID: AggregatedURLScore]) -> [URL: AggregatedURLScore] {
        var aggregatedScores = [URL: AggregatedURLScore]()
        for (url, urlIds) in groups {
            var acc = AggregatedURLScore()
            for urlId in urlIds {
                guard let score = scores[urlId] else { continue }
                acc = score.merge(other: acc)
            }
            aggregatedScores[url] = acc
        }
        return aggregatedScores
    }
    func getMostRecentTitles(links: [UUID: Link]) -> [URL: String] {
        var mostRecentTitle = [URL: String]()
        for (url, urlIds) in groups {
            var maxUpdatedAt = Date.distantPast
            for urlId in urlIds {
                guard let link = links[urlId],
                      let title = link.title else { continue }
                if link.updatedAt > maxUpdatedAt {
                    maxUpdatedAt = link.updatedAt
                    mostRecentTitle[url] = title
                }
            }
        }
        return mostRecentTitle
    }
}

fileprivate extension URL {
    var isSummaryEligible: Bool {
        !(isSearchEngineResultPage || isDomain)
    }
}

public class DailyUrlScorer {
    let store: DailyUrlScoreStoreProtocol
    let linkStore: LinkStore
    public private(set) var params = DailySummaryUrlParams(
        minReadingTime: 30,
        minTextAmount: 500,
        maxRepeatTimeFrame: 7,
        maxRepeat: 3
    )

    public init(store: DailyUrlScoreStoreProtocol, params: DailySummaryUrlParams? = nil, linkStore: LinkStore = LinkStore.shared) {
        self.store = store
        self.params = params ?? self.params
        self.linkStore = linkStore
    }
    public func getHighScoredUrls(between offset0: Int = 1, and offset1: Int = 1, topN: Int = 5, filtered: Bool = true) -> [ScoredURL] {
        let scores = store.getAggregatedScores(between: offset0, and: offset1)
        let links = linkStore.getLinks(for: Array(scores.keys))
            .filter { (id, link) in id != Link.missing.id || link.url != Link.missing.url }
        let urlGroups = UrlGroups(links: links).regroup { $0.fragmentRemoved }
        let schemeGroups = urlGroups.groupHTTPSchemes
        let mostRecentTitle = schemeGroups.getMostRecentTitles(links: links)
        let aggregatedScores = schemeGroups.aggregate(scores: scores)
        let repeatingUrls = store.getDailyRepeatingUrlsWithoutFragment(between: offset1 + params.maxRepeatTimeFrame, and: offset1, minRepeat: params.maxRepeat)
        return Array(
            aggregatedScores
                .filter { (url, score) in (score.isSummaryEligible(minReadingTime: params.minReadingTime, minTextAmount: params.minTextAmount)
                                           && url.isSummaryEligible && !repeatingUrls.contains(url.absoluteString))
                                           || !filtered
                }
                .sorted { (lhs, rhs) in lhs.value.score > rhs.value.score }
                .map { ScoredURL(url: $0.key, title: mostRecentTitle[$0.key], score: $0.value) }
                .prefix(topN)
        )
    }
}
