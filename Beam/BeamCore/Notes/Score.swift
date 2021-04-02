//
//  ScoreCard.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/11/2020.
//

import Foundation

public class Score: Codable {
    public var score: Float {
            readingTimeScore
            + textSelectionsScore
            + scrollRatioScore
            + openIndexScore
            + outboundsScore
            + densityScore
    }

    public var readingTime: CFTimeInterval = 0 //< how long did the user spent reading this page
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

    public var readingTimeScore: Float {
        Float(readingTime)
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
}
