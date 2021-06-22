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
}
