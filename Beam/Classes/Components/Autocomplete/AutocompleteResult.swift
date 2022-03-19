import Foundation
import Combine

// To improve the auto complete results we get, look at how chromium does it:
// https://chromium.googlesource.com/chromium/src/+/master/components/omnibox/browser/search_suggestion_parser.cc

struct AutocompleteResult: Identifiable, Equatable, Comparable, CustomStringConvertible {
    static func == (lhs: AutocompleteResult, rhs: AutocompleteResult) -> Bool {
        lhs.id == rhs.id
    }

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

    enum Source: Equatable, Hashable, Comparable {

        case history
        case note(noteId: UUID? = nil, elementId: UUID? = nil)
        case searchEngine
        case url
        case createNote
        case topDomain
        case mnemonic
        case action

        var iconName: String {
            switch self {
            case .history:
                return "field-history"
            case .searchEngine:
                return "field-search"
            case .createNote:
                return "field-card_new"
            case .note:
                return "field-card"
            case .action:
                return "tool-go"
            case .topDomain, .url, .mnemonic:
                return "field-web"
            }
        }
        static var note: Source {
            return Source.note(noteId: nil, elementId: nil)
        }

        static func < (lhs: AutocompleteResult.Source, rhs: AutocompleteResult.Source) -> Bool {
            lhs.priority > rhs.priority
        }
        /// lowest value priority means it's more important.
        private var priority: Int {
            switch self {
            case .history:
                return 0
            case .url:
                return 1
            case .note:
                return 2
            case .searchEngine:
                return 3
            case .action, .createNote:
                return 4
            case .topDomain, .mnemonic:
                return 5
            }
        }
    }

    var id: String {
        "\(uuid)\(completingText ?? "")"
    }
    private(set) var text: String
    private(set) var source: Source
    private(set) var disabled: Bool = false
    private(set) var url: URL?
    private(set) var aliasForDestinationURL: URL?
    private(set) var information: String?
    private var customIcon: String?
    private(set) var shortcut: Shortcut?
    private(set) var completingText: String?
    private(set) var additionalSearchTerms: [String]?
    private(set) var uuid: UUID
    private(set) var score: Float?
    private(set) var handler: ((BeamState) -> Void)?

    /// [0..1] depending on the comparison of the query vs the content of the text field. Can be compared to rawInfoPrefixScore
    private(set) var rawTextPrefixScore: Float
    /// [0..1] depending on the comparison of the query vs the content of the info field. Can be compared to rawTextPrefixScore
    private(set) var rawInfoPrefixScore: Float

    /// rawTextPrefixScore boosted by the type of the field (source kind + is it an url?)
    private(set) var textPrefixScore: Float
    /// rawInfoPrefixScore boosted by the type of the field (source kind + is it an url?)
    private(set) var infoPrefixScore: Float
    /// textPrefixScore and infoPrefixScore Combined
    private(set) var prefixScore: Float
    /// This option set tell us which of the String fields of this struct contains an URL. Right now only the "text" and "information" field can be a textual url. We use this to match the query with the start of the url (ignoring the scheme).
    private(set) var urlFields: URLFields
    private(set) var takeOverCandidate = false

    init(text: String, source: Source, disabled: Bool = false, url: URL? = nil, aliasForDestinationURL: URL? = nil,
         information: String? = nil, customIcon: String? = nil, shortcut: Shortcut? = nil, completingText: String? = nil, additionalSearchTerms: [String]? = nil,
         uuid: UUID = UUID(), score: Float? = nil, handler: ((BeamState) -> Void)? = nil, urlFields: URLFields = []) {
        self.text = text
        self.source = source
        self.disabled = disabled
        self.url = url
        self.aliasForDestinationURL = aliasForDestinationURL
        self.information = information
        self.customIcon = customIcon
        self.shortcut = shortcut
        self.completingText = completingText
        self.additionalSearchTerms = additionalSearchTerms
        self.uuid = uuid
        self.score = score
        self.handler = handler
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
        var canReplaceBase = true
        switch source {
        case .note, .createNote:
            canMatchInside = false
        case .searchEngine, .action:
            canReplaceBase = false
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

        if canMatchInside, canReplaceBase, let hsr = hsr, hsr.lowerBound <= maxSubstringIndex {
            newBase = String(base.suffix(from: base.index(at: hsr.lowerBound)))
        }

        let commonPrefixScore = skipScore + (1 - skipScoreWeight) * Float(hsr?.count ?? 0) / Float(comp.count)
        let score = commonPrefixScore
        let boosterWeight = typeWeight * (commonPrefixScore)

        // Only take over if we have a full match of the query and if the match is in the start of the string
        return BoosterResult(base: newBase, score: score, boostedScore: boosterWeight * score, takeOverCandidate: fullMatch && matchInRange)
    }

    /// The weighted score is used to sort AutocompleResults. It combines all subscore, higher is better.
    var weightedScore: Float {
        return (score ?? 1.0) * prefixScore
    }

    /// This is the main text to display.
    var displayText: String {
        [.note, .createNote].contains(source) ? text :
        (rawInfoPrefixScore > rawTextPrefixScore ? information ?? text : text)
    }

    /// This is the secondary text to display.
    var displayInformation: String? {
        rawInfoPrefixScore > rawTextPrefixScore ? text : information
    }

    /// inferior result means it should appear lower in the search results.
    static func < (lhs: AutocompleteResult, rhs: AutocompleteResult) -> Bool {
        let lScore = lhs.weightedScore
        let rScore = rhs.weightedScore
        if lScore != rScore {
            return lScore < rScore
        }
        if lhs.score != rhs.score {
            if lhs.score != nil { return false }
            if rhs.score != nil { return true }
        }
        if lhs.urlFields.contains(.text) {
            return lhs.text.count > rhs.text.count
        }
        return lhs.text < rhs.text
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

    var icon: String {
        customIcon ?? source.iconName
    }
}
