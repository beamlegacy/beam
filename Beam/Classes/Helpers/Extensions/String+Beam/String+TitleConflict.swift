import Foundation

public extension String {
    /// Will catch previous conflicted title and change from "title (2)" to "title" so if another conflict
    /// happens, it will change the title to "title (3)" and not "title (2) (2)".
    func originalTitleWithIndex() -> (String, Int) {
        let range = NSRange(location: 0, length: self.count)
        var index = 2
        var originalTitle = self

        guard let regex = try? NSRegularExpression(pattern: "\\A(.+) \\(([0-9-]+)\\)\\z"),
              let match = regex.firstMatch(in: self,
                                           options: [],
                                           range: range) else {
            return (originalTitle, index)
        }

        // Index
        var matchRange = match.range(at: 2)
        if let substringRange = Range(matchRange, in: self) {
            index = Int(String(originalTitle[substringRange])) ?? index
        }

        // Title
        matchRange = match.range(at: 1)
        if let substringRange = Range(matchRange, in: self) {
            originalTitle = String(originalTitle[substringRange])
        }

        return (originalTitle, index)
    }
}
