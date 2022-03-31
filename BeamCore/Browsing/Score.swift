//
//  ScoreCard.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/11/2020.
//

import Foundation

private let URL_SCORE_HALF_LIFE = Float(30.0 * 60.0)

private func aggregateLastEvent(event: ReadingEvent?, otherEvent: ReadingEvent?) -> ReadingEvent? {
    guard let unwrappedEvent = event, let unwrappedOtherEvent = otherEvent else { return event ?? otherEvent }
    return unwrappedEvent.date > unwrappedOtherEvent.date ? unwrappedEvent : unwrappedOtherEvent
}
private func nilMax(date: Date?, otherDate: Date?) -> Date? {
    guard let unwrappedDate = date, let unwrappedOtherDate = otherDate else { return date ?? otherDate }
    return max(unwrappedDate, unwrappedOtherDate)
}

extension Float {
    func almostEqual(_ other: Float, K: Float = 1) -> Bool {
        return abs(self - other) < K * .ulpOfOne * abs(self + other) || abs(self - other) < .leastNormalMagnitude
    }
}

extension Double {
    func almostEqual(_ other: Double, K: Double = 1) -> Bool {
        return abs(self - other) < K * .ulpOfOne * abs(self + other) || abs(self - other) < .leastNormalMagnitude
    }
}

public protocol UrlScoreProtocol: AnyObject {
    var urlId: UUID { get }
    var visitCount: Int { get set }
    var readingTimeToLastEvent: CFTimeInterval { get set }
    var textSelections: Int { get set }
    var scrollRatioX: Float { get set }
    var scrollRatioY: Float { get set }
    var textAmount: Int { get set }
    var area: Float { get set }
}

public class Score: Codable, Equatable {
    public static func == (lhs: Score, rhs: Score) -> Bool {
        return lhs.readingTimeToLastEvent.almostEqual(rhs.readingTimeToLastEvent)
        && lhs.textSelections == rhs.textSelections
        && lhs.scrollRatioX.almostEqual(rhs.scrollRatioX)
        && lhs.scrollRatioY.almostEqual(rhs.scrollRatioY)
        && lhs.openIndex == rhs.openIndex
        && lhs.outbounds == rhs.outbounds
        && lhs.textAmount == rhs.textAmount
        && lhs.area.almostEqual(rhs.area)
        && lhs.inbounds == rhs.inbounds
        && lhs.videoTotalDuration.almostEqual(rhs.videoTotalDuration)
        && lhs.videoReadingDuration.almostEqual(rhs.videoReadingDuration)
        && lhs.id == rhs.id
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case readingTimeToLastEvent = "readingTime"
        case textSelections
        case scrollRatioX
        case scrollRatioY
        case openIndex
        case outbounds
        case textAmount
        case area
        case inbounds
        case videoTotalDuration
        case videoReadingDuration
        case id
    }
    public var score: Float {
            readingTimeScore()
            + textSelectionsScore
            + scrollRatioScore
            + openIndexScore
            + outboundsScore
            + densityScore
    }

    public var id: UUID? = UUID()
    public var readingTimeToLastEvent: CFTimeInterval = 0 //< how long did the user spent reading this page
    public var textSelections: Int = 0 //< how many chunks of text were selected by the user
    public var scrollRatioX: Float = 0 //< how much of the page was seen by the user ([0, 1])
    public var scrollRatioY: Float = 0 //< how much of the page was seen by the user ([0, 1])
    public var openIndex: Int = 0 //< how many clicks on the search results page before this tab was created
    public var outbounds: Int = 0 //< how many links were followed from this page
    public var textAmount: Int = 0 //< amount of text (= the caracter counts from readability)
    public var area: Float = 0 //< the page area in points
    public var inbounds: Int = 0 //< Number of pages that reference this page
    public var videoTotalDuration: CFTimeInterval = 0 //< The number of seconds of the video objects cumulated
    public var videoReadingDuration: CFTimeInterval = 0 //< The number of seconds spent viewing video objects
    public var lastEvent: ReadingEvent?
    public var isForeground: Bool = false
    public var lastCreationDate: Date?

    public func readingTimeScore(toDate: Date = BeamDate.now) -> Float {
        guard let lastEvent = lastEvent else { return Float(readingTimeToLastEvent) }
        return Float(readingTimeToLastEvent + lastEvent.readingTime(isForeground: isForeground, toDate: toDate))
    }

    public var textSelectionsScore: Float {
        Float(textSelections)
    }

    public var scrollRatioScore: Float {
        (scrollRatioX + scrollRatioY) * 0.5
    }

    public var openIndexScore: Float {
        Float(openIndex)
    }

    public var outboundsScore: Float {
        Float(outbounds)
    }

    public var densityScore: Float {
        area > 0 ? Float(textAmount) / area : 0
    }

    public var videoScore: Float {
        videoTotalDuration > 0 ? Float(videoReadingDuration / videoTotalDuration) : 0
    }
    public var isClosed: Bool {
        guard let lastEvent = lastEvent else { return false }
        return lastEvent.isClosing
    }

    public func aggregate(_ other: Score) -> Score {
        let aggregated = Score()
        aggregated.readingTimeToLastEvent = readingTimeToLastEvent + other.readingTimeToLastEvent
        aggregated.textSelections = textSelections + other.textSelections
        aggregated.scrollRatioX = max(scrollRatioX, other.scrollRatioX)
        aggregated.scrollRatioY = max(scrollRatioY, other.scrollRatioY)
        aggregated.textAmount = max(textAmount, other.textAmount)
        aggregated.area = max(area, other.area)
        aggregated.videoTotalDuration = max(videoTotalDuration, other.videoTotalDuration)
        aggregated.videoReadingDuration = videoReadingDuration + other.videoReadingDuration
        aggregated.lastEvent = aggregateLastEvent(event: lastEvent, otherEvent: other.lastEvent)
        aggregated.isForeground = isForeground || other.isForeground
        aggregated.lastCreationDate = nilMax(date: lastCreationDate, otherDate: other.lastCreationDate)
        return aggregated
    }
    public func clusteringScore(date: Date) -> Float {
        return (exp(1 + scrollRatioY)
        * (1 + Float(textAmount))
        * (1 + readingTimeScore(toDate: date))
        )
    }

    public func clusteringRemovalScore(date: Date) -> Float {
        //The lesser score the more the url is to be removed
        guard let lastCreationDate = lastCreationDate else { return 0 }
        let timeSinceLastCreation = Float(date.timeIntervalSince(lastCreationDate))
        return (exp(-Float(timeSinceLastCreation) * log(2.0) / URL_SCORE_HALF_LIFE)
                * clusteringScore(date: date)
        )
    }
    public func clusteringRemovalLessThan(_ other: Score, date: Date) -> Bool {
        if isClosed && !other.isClosed { return true }
        if !isClosed && other.isClosed { return false }
        return clusteringRemovalScore(date: date) < other.clusteringRemovalScore(date: date)
    }
}
