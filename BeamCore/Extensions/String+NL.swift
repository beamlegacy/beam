import NaturalLanguage

public extension String {
    private func token(unit tokenUnit: NLTokenUnit, at index: String.Index) -> String {
        let tokenizer = NLTokenizer(unit: tokenUnit)
        tokenizer.string = self
        let substring = self[tokenizer.tokenRange(at: index)]
        return String(substring)
    }

    private func tokens(unit tokenUnit: NLTokenUnit, for indexRange: Range<String.Index>) -> String {
        let tokenizer = NLTokenizer(unit: tokenUnit)
        tokenizer.string = self
        let tokens = tokenizer.tokens(for: indexRange)
        guard tokens.count != 0 else {
            return ""
        }
        let lowerBound = tokens[0].lowerBound
        let upperBound = tokens[tokens.count - 1].upperBound
        let substring = self[lowerBound ..< upperBound]
        return String(substring)
    }

    func word(at index: String.Index) -> String {
        return token(unit: .word, at: index)
    }

    func sentence(at index: String.Index) -> String {
        return token(unit: .sentence, at: index)
    }

    func words(around indexRange: Range<String.Index>) -> String {
        return tokens(unit: .word, for: indexRange)
    }

    func sentences(around indexRange: Range<String.Index>) -> String {
        return tokens(unit: .sentence, for: indexRange)
    }

    var wordRanges: [Range<String.Index>] {
        return tokenize(.word, options: [.omitWhitespace, .joinContractions, .joinNames, .omitPunctuation])
    }

    var sentenceRanges: [Range<String.Index>] {
        return tokenize(.sentence, options: [.omitWhitespace, .joinContractions, .joinNames, .omitPunctuation])
    }

    func tokenize(_ tokenUnit: NLTokenUnit, options: NLTagger.Options? = nil) -> [Range<String.Index>] {
        var ranges = [Range<String.Index>]()

        // Use Natural Language's NLTagger to tokenize the input by word.
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = self

        let options: NLTagger.Options = options ?? [.omitWhitespace, .joinContractions, .joinNames]

        // Find all tokens in the string and append to the array.
        tagger.enumerateTags(in: self.startIndex..<self.endIndex,
                             unit: tokenUnit,
                             scheme: .tokenType,
                             options: options) { (_, range) -> Bool in
            ranges.append(range)
            return true
        }

        return ranges
    }
}
