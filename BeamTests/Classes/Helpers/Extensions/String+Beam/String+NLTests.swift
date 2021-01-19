import Foundation

import XCTest
@testable import Beam

class String_NLTests: XCTestCase {
    func testWordAndSentence() {
        let myString = "Hello, World! I am a test string for tokenization. Will this work?"
        let start = myString.startIndex
        let middle = myString.index(start, offsetBy: 30) // string
        let end = myString.index(before: myString.endIndex)

        XCTAssert(myString.word(at: start) == "Hello")
        XCTAssert(myString.sentence(at: start) == "Hello, World! ")

        XCTAssert(myString.word(at: middle) == "string")
        XCTAssert(myString.sentence(at: middle) == "I am a test string for tokenization. ")

        XCTAssert(myString.word(at: end) == "")
        XCTAssert(myString.sentence(at: end) == "Will this work?")
    }

    func testWordsAndSentences() {
        let myString = "Hello, World! This is a second test. Getting more complex..."
        let start = myString.index(myString.startIndex, offsetBy: 20) // is
        let end = myString.index(myString.startIndex, offsetBy: 48) // more

        XCTAssert(myString.words(around: start ..< end) == "is a second test. Getting more")
        XCTAssert(myString.sentences(around: start ..< end) == "This is a second test. Getting more complex...")
    }
}
