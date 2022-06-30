//
//  DailyUrlScore.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 28/03/2022.
//

import Foundation

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
    public func merge(other: AggregatedURLScore) -> AggregatedURLScore {
        return AggregatedURLScore(
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

public protocol DailyUrlScoreStoreProtocol {
    func apply(to urlId: UUID, changes: (DailyURLScore) -> Void)
    func getScores(daysAgo: Int) -> [UUID: DailyURLScore]
}

public struct AggregatedURLScore {
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
    func aggregate(scores: [UUID: DailyURLScore]) -> [URL: AggregatedURLScore] {
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
    let minReadingTime: Double
    let minTextAmount: Int
    let store: DailyUrlScoreStoreProtocol

    public init(store: DailyUrlScoreStoreProtocol, minReadingTime: Double = 30, minTextAmount: Int = 500) {
        self.store = store
        self.minReadingTime = minReadingTime
        self.minTextAmount = minTextAmount
    }
    public func getHighScoredUrls(daysAgo: Int = 1, topN: Int = 5, filtered: Bool = true) -> [ScoredURL] {
        let scores = store.getScores(daysAgo: daysAgo)
        let links = LinkStore.shared.getLinks(for: Array(scores.keys))
            .filter { (id, link) in id != Link.missing.id || link.url != Link.missing.url }
        let urlGroups = UrlGroups(links: links).regroup { $0.fragmentRemoved }
        let schemeGroups = urlGroups.groupHTTPSchemes
        let mostRecentTitle = schemeGroups.getMostRecentTitles(links: links)
        let aggregatedScores = schemeGroups.aggregate(scores: scores)
        return Array(
            aggregatedScores
                .filter { (url, score) in (score.isSummaryEligible(minReadingTime: minReadingTime, minTextAmount: minTextAmount)
                                           && url.isSummaryEligible)
                                           || !filtered
                }
                .sorted { (lhs, rhs) in lhs.value.score > rhs.value.score }
                .map { ScoredURL(url: $0.key, title: mostRecentTitle[$0.key], score: $0.value) }
                .prefix(topN)
        )
    }
}
