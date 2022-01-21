import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutocompleteResult: Identifiable, Equatable, Comparable, CustomStringConvertible {

    struct URLFields: OptionSet {
        let rawValue: Int

        static let text = URLFields(rawValue: 1 << 0)
        static let info = URLFields(rawValue: 1 << 1)

        var description: String {
            var str = [String]()
            if self.contains(.text) {
                str.append("text")
            }
            if self.contains(.info) {
                str.append("info")
            }

            return str.joined(separator: "+")
        }
    }

    enum Source: Equatable, Hashable {
        case history
        case note(noteId: UUID? = nil, elementId: UUID? = nil)
        case autocomplete
        case url
        case createCard
        case topDomain
        case mnemonic

        var iconName: String {
            switch self {
            case .history:
                return "field-history"
            case .autocomplete:
                return "field-search"
            case .createCard:
                return "field-card_new"
            case .note:
                return "field-card"
            case .topDomain, .url, .mnemonic:
                return "field-web"
            }
        }
        static var note: Source {
            return Source.note(noteId: nil, elementId: nil)
        }

        var priority: Int {
            switch self {
            case .history:
                return 0
            case .url:
                return 1
            case .autocomplete:
                return 2
            case .note:
                return 3
            case .createCard:
                return 4
            case .topDomain, .mnemonic:
                return 5
            }
        }
    }

    var id: String {
        "\(uuid)\(completingText ?? "")"
    }
    var text: String
    var source: Source
    var disabled: Bool = false
    var url: URL?
    var information: String?
    var completingText: String?
    var uuid: UUID
    var score: Float?

    /// [0..1] depending on the comparison of the query vs the content of the text field. Can be compared to rawInfoPrefixScore
    var rawTextPrefixScore: Float
    /// [0..1] depending on the comparison of the query vs the content of the info field. Can be compared to rawTextPrefixScore
    var rawInfoPrefixScore: Float

    /// rawTextPrefixScore boosted by the type of the field (source kind + is it an url?)
    var textPrefixScore: Float
    /// rawInfoPrefixScore boosted by the type of the field (source kind + is it an url?)
    var infoPrefixScore: Float
    /// textPrefixScore and infoPrefixScore Combined
    var prefixScore: Float
    /// This option set tell us which of the String fields of this struct contains an URL. Right now only the "text" and "information" field can be a textual url. We use this to match the query with the start of the url (ignoring the scheme).
    var urlFields: URLFields
    var takeOverCandidate = false

    init(text: String, source: Source, disabled: Bool = false, url: URL? = nil, information: String? = nil, completingText: String? = nil, uuid: UUID = UUID(), score: Float? = nil, urlFields: URLFields = []) {
        self.text = text
        self.source = source
        self.disabled = disabled
        self.url = url
        self.information = information
        self.completingText = completingText
        self.uuid = uuid
        self.score = score
        self.urlFields = urlFields

        let textResult = Self.boosterScore(prefix: completingText, base: text, isURL: urlFields.contains(.text), source: source)
        self.text = textResult.base ?? text
        rawTextPrefixScore = textResult.score
        textPrefixScore = textResult.boostedScore
        takeOverCandidate = takeOverCandidate || textResult.takeOverCandidate

        let infoResult = Self.boosterScore(prefix: completingText, base: information, isURL: urlFields.contains(.info), source: source)
        self.information = infoResult.base
        rawInfoPrefixScore = infoResult.score
        infoPrefixScore = infoResult.boostedScore
        takeOverCandidate = takeOverCandidate || infoResult.takeOverCandidate

        prefixScore = 1.0 + textPrefixScore + infoPrefixScore
    }

    private struct BoosterResult {
        var base: String?
        var score: Float
        var boostedScore: Float
        var takeOverCandidate = false
    }

    private static func simpleBoosterScore(prefix: String?, base: String?, isURL: Bool) -> BoosterResult {
        guard let lcbase = base?.lowercased(),
              !lcbase.isEmpty,
              let comp = prefix?.lowercased()
        else {
            return BoosterResult(base: base, score: 0.0, boostedScore: 0.0)
        }

        let booster: Float = isURL ? 0.2 : 0.1
        let hsr = lcbase.commonPrefix(with: comp)
        let score = Float(hsr.count) / Float(comp.count)
        return BoosterResult(base: base, score: score, boostedScore: booster * score, takeOverCandidate: score >= 1.0)
    }

    private static func boosterScore(prefix: String?, base: String?, isURL: Bool, source: Source) -> BoosterResult {
        var canMatchInside = !isURL

        switch source {
        case .note, .createCard:
            canMatchInside = false
        default:
            break
        }

        guard canMatchInside else { return simpleBoosterScore(prefix: prefix, base: base, isURL: isURL) }

        guard let base = base,
              !base.isEmpty,
              let comp = prefix else {
                  return BoosterResult(base: base, score: 0.0, boostedScore: 0.0)
        }

        // look for a common prefix:
        let hsr = base.longestCommonPrefixRange(comp)

        let maxSubstringIndex = 10

        let skipScoreWeight = Float(canMatchInside ? 0.1 : 0)
        let typeWeight = Float(isURL ? 0.1 : 0.05)
        // Skip score, [0-1] is a penalty computed on the position of the substring in the main string.
        let fullMatch = hsr?.count == comp.count
        let matchInRange = (hsr?.lowerBound ?? maxSubstringIndex + 1) <= maxSubstringIndex
        let skipScore = skipScoreWeight * Float(maxSubstringIndex - min(hsr?.lowerBound ?? 0, maxSubstringIndex)) / Float(maxSubstringIndex)

        var newBase = base

        if canMatchInside, let hsr = hsr, hsr.lowerBound <= maxSubstringIndex {
            newBase = String(base.suffix(from: base.index(at: hsr.lowerBound)))
        }

        let commonPrefixScore = skipScore + (1 - skipScoreWeight) * Float(hsr?.count ?? 0) / Float(comp.count)
        let score = commonPrefixScore
        let boosterWeight = typeWeight * (commonPrefixScore)

        // Only take over if we have a full match of the query and if the match is in the start of the string
        return BoosterResult(base: newBase, score: score, boostedScore: boosterWeight * score, takeOverCandidate: fullMatch && matchInRange)
    }

    /// The weighted score is used to sort AutocompleResults. It combines all subscore, higher is better. Can be nil if there is no original score.
    var weightedScore: Float? {
        return (score ?? 1.0) * prefixScore
    }

    /// This is the main text to display.
    var displayText: String {
        [.note, .createCard].contains(source) ? text :
        (rawInfoPrefixScore > rawTextPrefixScore ? information ?? text : text)
    }

    /// This is the secondary text to display.
    var displayInformation: String? {
        rawInfoPrefixScore > rawTextPrefixScore ? text : information
    }

    static func < (lhs: AutocompleteResult, rhs: AutocompleteResult) -> Bool {
        if let slhs = lhs.weightedScore,
           let srhs = rhs.weightedScore {
            if slhs == srhs {
                return lhs.text < rhs.text
            }
            return slhs < srhs
        }
        if lhs.score != nil { return false }
        if rhs.score != nil { return true }
        return lhs.text.count < rhs.text.count

    }
    var description: String {
        var urlToPrint: String
        if let url = url {
            urlToPrint = "\(url.host ?? "")\(url.path)"
        } else {
            urlToPrint = "<???>"
        }
        return "id: \(id) text: \(text) - source: \(source) - url: \(urlToPrint) - score: \(score ?? Float.nan)"
    }
}

class Autocompleter: ObservableObject {

    private(set) var searchEngine: SearchEngineDescription

    private var lastDataTask: URLSessionDataTask?

    init(searchEngine: SearchEngineDescription) {
        self.searchEngine = searchEngine
    }

    public func complete(query: String) -> Future<[AutocompleteResult], Never> {
        Future { promise in
            guard !query.isEmpty,
                  let url = self.searchEngine.suggestionsURL(forQuery: query)
            else {
                promise(.success([]))
                return
            }

            self.lastDataTask?.cancel()
            let description = self.searchEngine.description
            self.lastDataTask = BeamURLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error as? URLError, error.code == .cancelled {
                    return
                }

                var res = [AutocompleteResult]()
                if query.containsCharacters {
                    res.append(AutocompleteResult(text: query, source: .autocomplete, url: url, information: description))
                }
                guard let data = data else {
                    promise(.success(res))
                    return
                }

                res = []

                for (index, str) in self.searchEngine.suggestions(from: data).enumerated() {
                    let isURL = str.mayBeWebURL
                    let source: AutocompleteResult.Source = isURL ? .url : .autocomplete
                    let url = isURL ? URL(string: str) : nil
                    var text = str
                    let info = (index == 0 && url == nil) ? description : nil
                    if let url = url {
                        text = url.urlStringWithoutScheme
                    }
                    let result = AutocompleteResult(
                        text: text,
                        source: source,
                        url: url,
                        information: info,
                        completingText: query,
                        urlFields: []
                    )
                    res.append(result)
                }
                promise(.success(res))
            }
            self.lastDataTask?.resume()
        }
    }

    public func clear() {
        lastDataTask?.cancel()
    }
}
