//
//  ScoreCard.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/11/2020.
//

import Foundation

class Scores: Codable {
    private var cards: [UInt64: Score] = [:]
    func scoreCard(for id: UInt64) -> Score {
        if let card = cards[id] {
            return card
        }

        let card = Score()
        cards[id] = card
        return card
    }

    func scoreCard(for link: String) -> Score {
        return scoreCard(for: LinkStore.createIdFor(link))
    }
}

class Score: Codable {
    var score: Float {
            readingTimeScore
            + textSelectionsScore
            + scrollRatioScore
            + openIndexScore
            + outboundsScore
            + densityScore
    }

    var readingTime: CFTimeInterval = 0 //< how long did the user spent reading this page
    var textSelections: Int = 0 //< how many chunks of text were selected by the user
    var scrollRatioX: Float = 0 //< how much of the page was seen by the user ([0, 1])
    var scrollRatioY: Float = 0 //< how much of the page was seen by the user ([0, 1])
    var openIndex: Int = 0 //< how many clicks on the search results page before this tab was created
    var outbounds: Int = 0 //< how many links were followed from this page
    var textAmount: Int = 0 //< amount of text (= the caracter counts from readability)
    var area: Float = 0 //< the page area in points
    var inbounds: Int = 0 //< Number of pages that reference this page
    var videoTotalDuration: CFTimeInterval = 0 //< The number of seconds of the video objects cumulated
    var videoReadingDuration: CFTimeInterval = 0 //< The number of seconds spent viewing video objects

    var readingTimeScore: Float {
        Float(readingTime)
    }

    var textSelectionsScore: Float {
        Float(textSelections)
    }

    var scrollRatioScore: Float {
        (scrollRatioX + scrollRatioY) * 0.5
    }

    var openIndexScore: Float {
        Float(openIndex)
    }

    var outboundsScore: Float {
        Float(outbounds)
    }

    var densityScore: Float {
        area > 0 ? Float(textAmount) / area : 0
    }

    var videoScore: Float {
        videoTotalDuration > 0 ? Float(videoReadingDuration / videoTotalDuration) : 0
    }
}
