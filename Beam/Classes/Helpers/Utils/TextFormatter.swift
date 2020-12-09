import Foundation

class TextFormatter {
    static let linkPatterns: [String] = ["\\[\\[(.+?)\\]\\]", "\\#([^\\#\\s]+)"]

    class func parseForInternalLinks(_ string: String) -> String {
        var result = string

        for pattern in linkPatterns {
            var regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                // TODO: manage errors
                fatalError("Error")
            }

            for match in regex.matches(in: result,
                          options: [],
                          range: NSRange(location: 0, length: result.count)).reversed() {
                guard let linkRange = Range(match.range(at: 1), in: result) else { continue }

                let linkTitle = String(result[linkRange])
                result.replaceSubrange(linkRange, with: "[\(linkTitle)](\(Note.internalLink(linkTitle)))")
            }
        }

        return result
    }
}
