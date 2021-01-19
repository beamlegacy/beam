import NaturalLanguage
import XCTest

class NLPTests: XCTestCase {
    func testNLLanguageRecognizer() throws {
        let ENGLISH = "en"
        let GERMAN  = "de"

        let recognizer = NLLanguageRecognizer()
        recognizer.processString("This is a test, mein Freund.")
        XCTAssertNotNil(recognizer.dominantLanguage)
        XCTAssert(recognizer.dominantLanguage?.rawValue == ENGLISH)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        XCTAssert(hypotheses.count == 2)
        for nl in hypotheses.keys {
            XCTAssert(nl.rawValue == ENGLISH || nl.rawValue == GERMAN)
        }
    }

    func testNLTokenizer() throws {
        let text = """
            Boys have generally excellent appetites. Oliver Twist and his [companions] suffered the tortures of slow starvation for three months. @ At last they got so voracious and wild with hunger, that one boy who was tall for his age, hinted darkly to his companions that unless he had another *** basin of gruel, he was afraid he might some night happen to eat the boy sleeping next to him, who happened to be a weakly youth of tender age. He had a wild, hungry eye and they implicitly 0000 believed him. A council was held; lots were cast for who should walk up to the master after supper that evening and ask for more; and it fell =+to Oliver Twist.
            """
        
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        XCTAssert(tokenizer.tokens(for: text.startIndex..<text.endIndex).count == 118)
        XCTAssert(text[tokenizer.tokenRange(at: text.index(text.startIndex, offsetBy: 50))] == "Twist")
    }
    
    func testLematizationEN() {
        let text = "This is a Swift port of Ruby's Faker library that generates fake data. Are you still bothered with meaningless randomly character strings? Just relax and leave this job to Fakery. It's useful in all the cases when you need to use some dummy data for testing, population of database during development, etc. NOTE: Generated data is pretty realistic, supports a range of locales, but returned values are not guaranteed to be unique."

        let tagger = NLTagger(tagSchemes: [.lemma])

        tagger.string = text
        let range = text.startIndex ..< text.endIndex
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        print("Found language: \(String(describing: tagger.dominantLanguage))")
        XCTAssertEqual(tagger.dominantLanguage, .english)

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange -> Bool in
            if let lemma = tag?.rawValue {
                // Do something with each lemma
//                let range = text.range(from: tokenRange.lowerBound ..< tokenRange.upperBound)
                let range = text[tokenRange]
                print("Lema: \(range) -> \(lemma)")
            }

            return true
        }
    }

    func testLematizationFR() {
        let text = "Le Monde et des tiers selectionnés, notamment des partenaires publicitaires, utilisent des cookies ou des technologies similaires. Les cookies nous permettent d’accéder à, d’analyser et de stocker des informations telles que les caractéristiques de votre terminal ainsi que certaines données personnelles (par exemple : adresses IP, données de navigation, d’utilisation ou de géolocalisation, identifiants uniques)."

        let tagger = NLTagger(tagSchemes: [.lemma])

        tagger.string = text
        let range = text.startIndex ..< text.endIndex
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        print("Found language: \(String(describing: tagger.dominantLanguage))")
        XCTAssertEqual(tagger.dominantLanguage, .french)

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange -> Bool in
            if let lemma = tag?.rawValue {
                // Do something with each lemma
//                let range = text.range(from: tokenRange.lowerBound ..< tokenRange.upperBound)
                let range = text[tokenRange]
                print("Lema: \(range) -> \(lemma)")
            }
            return true
        }
    }
}
