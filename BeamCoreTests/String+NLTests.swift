//
//  String+NLTests.swift
//  BeamCoreTests
//
//  Created by Sebastien Metrot on 24/08/2021.
//

import Foundation
import XCTest

class StringNLTokenizerTests: XCTestCase {
    func testCanTokenizeSentenseIntoWords() {
        let sentence = "I'm working hard to make beam better, much better"
        let words = ["I'm", "working", "hard", "to", "make", "beam", "better", "much", "better"]
        let tokens = sentence.wordRanges
        XCTAssertEqual(tokens.count, words.count)
        XCTAssertEqual(tokens.map({ wordRange in String(sentence[wordRange]) }), words)
    }

    func testCanTokenizeSentenses() {
        let phrases = "I'm working hard to make beam better, much better. It makes me very happy every day."
        let sentences = ["I'm working hard to make beam better, much better. ", "It makes me very happy every day."]
        let tokens = phrases.sentenceRanges
        XCTAssertEqual(tokens.count, sentences.count)
        XCTAssertEqual(tokens.map({ sentenceRange in String(phrases[sentenceRange]) }), sentences)
    }
}
