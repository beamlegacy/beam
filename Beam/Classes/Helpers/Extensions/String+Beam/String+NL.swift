import NaturalLanguage

extension String {
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

    func extractWords(useLemmas: Bool, removeDiacritics: Bool) -> [String] {
        // Store the tokenized substrings into an array.
        var wordTokens = [String]()

        // Use Natural Language's NLTagger to tokenize the input by word.
        let tagger = NLTagger(tagSchemes: [.tokenType, .lemma])
        tagger.string = self

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinContractions]

        // Find all tokens in the string and append to the array.
        tagger.enumerateTags(in: self.startIndex..<self.endIndex,
                             unit: .word,
                             scheme: useLemmas ? .lemma : .tokenType,
                             options: options) { (tag, range) -> Bool in
            if useLemmas {
                if let lemma = tag?.rawValue {
                    wordTokens.append(removeDiacritics ? lemma.folding(options: .diacriticInsensitive, locale: .current) : lemma)
                } else {
                    let word = String(self[range].lowercased())
                    wordTokens.append(removeDiacritics ? word.folding(options: .diacriticInsensitive, locale: .current) : word)
                    //Logger.shared.logDebug("no lemma found for word '\(word)'")
                }
            } else {
                let word = String(self[range].lowercased())
                wordTokens.append(removeDiacritics ? word.folding(options: .diacriticInsensitive, locale: .current) : word)
            }
            return true
        }

        return wordTokens
    }

    var namedEntities: [(String, NLTag)] {
        return getNamedEntities(nil)
    }

    func getNamedEntities(_ language: NLLanguage?) -> [(String, NLTag)] {
        var entities = [(String, NLTag)]()
        let tagger = NLTagger(tagSchemes: [.nameType])

        tagger.string = self
        if let language = language {
            tagger.setLanguage(language, range: self.startIndex ..< self.endIndex)
        }

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let tags: [NLTag] = [.personalName, .placeName, .organizationName]
        tagger.enumerateTags(in: self.startIndex..<self.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: options) { (tag, range) -> Bool in
            if let tag = tag, tags.contains(tag) {
                let entity = String(self[range])
                entities.append((entity, tag))
            }
            return true
        }

        return entities
    }

}
