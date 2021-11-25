import BeamCore
import NaturalLanguage

struct IndexDocument: Codable {
    var id: UUID
    var title: String = ""
    var language: NLLanguage = .undetermined
    var length: Int = 0
    var contentsWords = [String]()
    var titleWords = [String]()
    var tagsWords = [String]()
    var outboundLinks = [UUID]()

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case title = "t"
    }
}

extension IndexDocument {
    init(source: String, title: String, language: NLLanguage? = nil, contents: String, outboundLinks: [String] = []) {
        self.id = LinkStore.getOrCreateIdFor(source, title: title)
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        self.outboundLinks = outboundLinks.compactMap({ link -> UUID? in
            // Only register links that points to cards or to pages we have really visited:
            let id = LinkStore.getOrCreateIdFor(link)
//            guard LinkStore.isInternalLink(id: id) else { return nil }
            return id
        })
        length = contents.count
    }

    var leanCopy: IndexDocument {
        return IndexDocument(id: id, title: title, language: language, length: length, contentsWords: [], titleWords: [], tagsWords: [])
    }
}
